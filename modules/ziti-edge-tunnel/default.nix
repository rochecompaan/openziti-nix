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
  };

  config = mkIf cfg.enable {
    environment.systemPackages = [ pkgs.ziti-edge-tunnel ];

    systemd.services.ziti-edge-tunnel = mkIf cfg.service.enable {
      description = "Ziti Edge Tunnel";
      wantedBy = [ "multi-user.target" ];
      after = [ "network-online.target" ];
      wants = [ "network-online.target" ];
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
    users.groups.${cfg.service.group} = {};
  };
}
