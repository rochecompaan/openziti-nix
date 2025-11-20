{ lib, config, pkgs, ... }:

with lib;

let
  cfg = config.programs.ziti;
in
{
  options.programs.ziti = {
    enable = mkEnableOption "Ziti CLI";
  };

  config = mkIf cfg.enable {
    environment.systemPackages = [ pkgs.ziti-cli ];
  };
}
