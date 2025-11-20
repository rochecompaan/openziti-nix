{
  description = "OpenZiti packages and NixOS modules (ziti-cli, ziti-edge-tunnel)";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs = { self, nixpkgs }:
    let
      systems = [ "x86_64-linux" "aarch64-linux" ];
      forAllSystems = f: builtins.listToAttrs (map (system: { name = system; value = f system; }) systems);

      overlay = final: prev: {
        ziti-cli = final.callPackage ./pkgs/ziti-cli { };
        ziti-edge-tunnel = final.callPackage ./pkgs/ziti-edge-tunnel { };
      };

      mkPkgs = system: import nixpkgs { inherit system; overlays = [ overlay ]; };
    in
    {
      overlays.default = overlay;

      packages = forAllSystems (system:
        let pkgs = mkPkgs system; in {
          inherit (pkgs) ziti-cli ziti-edge-tunnel;
          default = pkgs.ziti-cli;
        }
      );

      nixosModules = {
        ziti = import ./modules/ziti;
        ziti-edge-tunnel = import ./modules/ziti-edge-tunnel;
        withOverlays = { lib, ... }: { nixpkgs.overlays = [ overlay ]; };
        default = { lib, ... }: {
          imports = [
            self.nixosModules.withOverlays
            self.nixosModules.ziti
            self.nixosModules.ziti-edge-tunnel
          ];
        };
      };
    };
}
