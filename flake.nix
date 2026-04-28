{
  description = "OpenZiti packages and NixOS modules (ziti-cli, ziti-edge-tunnel)";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs =
    { self, nixpkgs }:
    let
      systems = [
        "x86_64-linux"
        "aarch64-linux"
      ];
      forAllSystems =
        f:
        builtins.listToAttrs (
          map (system: {
            name = system;
            value = f system;
          }) systems
        );

      overlay = final: prev:
        let
          # ziti currently requires Go >= 1.26.2, while nixpkgs still ships 1.26.1.
          go_1_26 = prev.go_1_26.overrideAttrs (old: rec {
            version = "1.26.2";
            src = prev.fetchurl {
              url = "https://go.dev/dl/go${version}.src.tar.gz";
              hash = "sha256-LpHrtpR6lulDb7KzkmqIAu/mOm03Xf/sT4Kqnb1v1Ds=";
            };
          });

          buildGo126Module = prev.callPackage (prev.path + "/pkgs/build-support/go/module.nix") {
            go = final.buildPackages.go_1_26;
          };
        in
        {
          inherit go_1_26 buildGo126Module;
          stc = prev.stc or (final.callPackage ./pkgs/stc { });
          ziti = final.callPackage ./pkgs/ziti { };
          ziti-edge-tunnel = final.callPackage ./pkgs/ziti-edge-tunnel { };
        };

      mkPkgs =
        system:
        import nixpkgs {
          inherit system;
          overlays = [ overlay ];
        };
    in
    {
      overlays.default = overlay;

      packages = forAllSystems (
        system:
        let
          pkgs = mkPkgs system;
        in
        {
          inherit (pkgs) ziti ziti-edge-tunnel;
          default = pkgs.ziti;
        }
      );

      # Use tree wrapper so `nix fmt .` works without deprecation
      formatter = forAllSystems (system: nixpkgs.legacyPackages.${system}.nixfmt-tree);

      nixosModules = {
        ziti = import ./modules/ziti;
        ziti-edge-tunnel = import ./modules/ziti-edge-tunnel;
        ziti-router = import ./modules/ziti-router;
        withOverlays =
          { lib, ... }:
          {
            nixpkgs.overlays = [ overlay ];
          };
        default =
          { lib, ... }:
          {
            imports = [
              self.nixosModules.withOverlays
              self.nixosModules.ziti
              self.nixosModules.ziti-edge-tunnel
              self.nixosModules.ziti-router
            ];
          };
      };
    };
}
