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
    service.enable = mkEnableOption "Ziti Edge Tunnel service";
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
        ExecStart = "${pkgs.ziti-edge-tunnel}/bin/ziti-edge-tunnel run -I /opt/openziti/etc/identities";
        Restart = "on-failure";
      };
    };
  };
}
