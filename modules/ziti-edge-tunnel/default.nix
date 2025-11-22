{
  lib,
  config,
  pkgs,
  ...
}:

with lib;

let
  cfg = config.programs.ziti-edge-tunnel;
in
{
  options.programs.ziti-edge-tunnel = {
    enable = mkEnableOption "Ziti Edge Tunnel";
    service = {
      enable = mkEnableOption "Ziti Edge Tunnel service";
      identityDir = mkOption {
        type = types.str;
        default = "/opt/openziti/etc/identities";
        description = "Directory containing Ziti identities used by the tunnel";
      };
      group = mkOption {
        type = types.str;
        default = "ziti";
        description = "Group owning identities; contents are writable by this group";
      };
    };

    enrollment = {
      enable = mkEnableOption "Enroll an identity for the edge tunnel at boot";
      jwtFile = mkOption {
        type = types.str;
        default = "";
        description = ''
          Path to the enrollment JWT. This can point to a sops-nix secret like
          `config.sops.secrets."ziti-jwt".path`.
        '';
      };
      identityFile = mkOption {
        type = types.str;
        default = "${config.programs.ziti-edge-tunnel.service.identityDir}/myidentity.json";
        description = "Absolute path of the enrolled identity JSON to create if missing.";
      };
      extraArgs = mkOption {
        type = with types; listOf str;
        default = [];
        description = "Extra flags to pass to `ziti-edge-tunnel enroll`.";
      };
    };
  };

  config = mkIf cfg.enable {
    environment.systemPackages = [ pkgs.ziti-edge-tunnel ];

    systemd.services.ziti-edge-tunnel = mkIf cfg.service.enable {
      description = "Ziti Edge Tunnel";
      wantedBy = [ "multi-user.target" ];
      after = [ "network-online.target" ]
        ++ lib.optionals cfg.enrollment.enable [ "ziti-edge-tunnel-enroll.service" ];
      wants = [ "network-online.target" ]
        ++ lib.optionals cfg.enrollment.enable [ "ziti-edge-tunnel-enroll.service" ];
      path = [ pkgs.iproute2 ];

      serviceConfig = {
        Type = "exec";
        ExecStart = "${pkgs.ziti-edge-tunnel}/bin/ziti-edge-tunnel run -I ${cfg.service.identityDir}";
        Restart = "on-failure";
      };
    };

    # Ensure identity directory exists with secure defaults and proper group
    systemd.tmpfiles.rules = [
      "d ${cfg.service.identityDir} 0770 root ${cfg.service.group} -"
    ];

    # Ensure recursive ownership and permissions match policy:
    # - group=${cfg.service.group}
    # - ug=rwX,o-rwx
    systemd.services.ziti-edge-tunnel-identities-perms = {
      description = "Normalize Ziti identities directory ownership and permissions";
      wantedBy = [ "multi-user.target" ];
      before = [ "ziti-edge-tunnel.service" ];
      after = [ "local-fs.target" ];
      serviceConfig = {
        Type = "oneshot";
        ExecStart = [
          "${pkgs.coreutils}/bin/chgrp -cR ${cfg.service.group} ${cfg.service.identityDir}"
          "${pkgs.coreutils}/bin/chmod -cR ug=rwX,o-rwx ${cfg.service.identityDir}"
        ];
      };
    };

    # Declare the group to ensure it exists
    users.groups.${cfg.service.group} = { };

    # Enrollment one-shot service
    systemd.services.ziti-edge-tunnel-enroll = mkIf cfg.enrollment.enable {
      description = "Enroll Ziti Edge Tunnel identity";
      after = [ "network-online.target" "local-fs.target" ];
      wants = [ "network-online.target" ];
      before = [ "ziti-edge-tunnel.service" ];
      serviceConfig = {
        Type = "oneshot";
        ConditionPathExists = "!${cfg.enrollment.identityFile}";
        ExecStart = ''
          ${pkgs.ziti-edge-tunnel}/bin/ziti-edge-tunnel enroll \
            --jwt ${lib.escapeShellArg cfg.enrollment.jwtFile} \
            --identity ${lib.escapeShellArg cfg.enrollment.identityFile} \
            ${lib.concatStringsSep " " (map lib.escapeShellArg cfg.enrollment.extraArgs)}
        '';
        ExecStartPost = [
          "${pkgs.coreutils}/bin/chgrp ${cfg.service.group} ${lib.escapeShellArg cfg.enrollment.identityFile}"
          "${pkgs.coreutils}/bin/chmod ug=rw,o-rwx ${lib.escapeShellArg cfg.enrollment.identityFile}"
        ];
      };
    };
  };
}
