{
  lib,
  config,
  pkgs,
  ...
}:

with lib;

let
  cfg = config.programs.ziti-router;
  svc = cfg.service;
in
{
  options.programs.ziti-router = {
    enable = mkEnableOption "OpenZiti Router package available in the system";

      package = mkOption {
        type = types.package;
        default = pkgs.ziti;
        defaultText = literalExpression "pkgs.ziti";
        description = "Package providing the `ziti` binary used to run the router (invoked as `ziti router run`).";
      };

    service = {
      enable = mkEnableOption "OpenZiti Router systemd service";

      name = mkOption {
        type = types.str;
        default = "router";
        description = "Router instance name used for file paths.";
      };

      user = mkOption {
        type = types.str;
        default = "ziti-router";
        description = "User to run the router under.";
      };

      group = mkOption {
        type = types.str;
        default = "ziti";
        description = "Group owning router files and directories.";
      };

      stateDir = mkOption {
        type = types.str;
        default = "/var/lib/ziti/${svc.name}";
        description = "State directory for the router (identities, runtime files).";
      };

      configFile = mkOption {
        type = types.str;
        default = "/etc/ziti/${svc.name}.json";
        description = "Path to the router configuration file (JSON).";
      };

      config = mkOption {
        type = types.attrs;
        default = { };
        description = "Router configuration as a Nix attribute set, serialized to JSON.";
        example = {
          identity = {
            cert = "/var/lib/ziti/router/router.cert";
            server_key = "/var/lib/ziti/router/router.key";
            server_cert = "/var/lib/ziti/router/router.cert";
          };
          ctrl = {
            endpoint = "tls:controller.example.com:443";
          };
          listeners = [
            {
              binding = "edge";
              address = "0.0.0.0:3022";
            }
          ];
        };
      };

      extraArgs = mkOption {
        type = with types; listOf str;
        default = [ ];
        description = "Extra command-line arguments for ziti-router run.";
      };

      environment = mkOption {
        type = types.attrsOf types.str;
        default = { };
        description = "Extra environment variables for the service.";
      };
    };
  };

  config = mkMerge [
    (mkIf cfg.enable {
      environment.systemPackages = [ cfg.package ];
    })

    (mkIf svc.enable {
      users.groups.${svc.group} = { };
      users.users.${svc.user} = {
        isSystemUser = true;
        group = svc.group;
      };

      # Ensure directories exist with proper ownership
      systemd.tmpfiles.rules = [
        "d ${svc.stateDir} 0750 ${svc.user} ${svc.group} -"
        "d ${dirOf svc.configFile} 0750 root ${svc.group} -"
      ];

      # Serialize config to JSON if provided
      environment.etc."ziti/${svc.name}.json" = mkIf (svc.config != { }) {
        mode = "0640";
        user = svc.user;
        group = svc.group;
        text = builtins.toJSON svc.config;
      };

      systemd.services.ziti-router = {
        description = "OpenZiti Router (${svc.name})";
        wantedBy = [ "multi-user.target" ];
        after = [ "network-online.target" ];
        wants = [ "network-online.target" ];

        serviceConfig = {
          Type = "exec";
          User = svc.user;
          Group = svc.group;
          ExecStart = ''${cfg.package}/bin/ziti router run ${svc.configFile} ${lib.escapeShellArgs svc.extraArgs}'';
          Restart = "on-failure";
          WorkingDirectory = svc.stateDir;
        };

        environment = svc.environment;
      };
    })
  ];
}
