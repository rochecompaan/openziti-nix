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

      overlay =
        final: prev:
        let
          # Ziti requires Go >= 1.26.2. Keep this Go private to Ziti builds so
          # applying the overlay does not replace nixpkgs' go_1_26 globally.
          zitiGo_1_26 =
            if prev.lib.versionAtLeast prev.buildPackages.go_1_26.version "1.26.2" then
              prev.buildPackages.go_1_26
            else
              prev.buildPackages.go_1_26.overrideAttrs (_old: rec {
                version = "1.26.2";
                src = prev.fetchurl {
                  url = "https://go.dev/dl/go${version}.src.tar.gz";
                  hash = "sha256-LpHrtpR6lulDb7KzkmqIAu/mOm03Xf/sT4Kqnb1v1Ds=";
                };
              });

          zitiBuildGo126Module = prev.callPackage (prev.path + "/pkgs/build-support/go/module.nix") {
            go = zitiGo_1_26;
          };
        in
        {
          stc = prev.stc or (final.callPackage ./pkgs/stc { });
          ziti_1 = final.callPackage ./pkgs/ziti {
            buildGo126Module = zitiBuildGo126Module;
            version = "1.6.15";
            srcHash = "sha256-Lvm7iWKDx3IYUsWTzrpuEaKSp0A/5zUGO+XxOJwzCkY=";
            vendorHash = "sha256-nGOSIwyIYYN1lKMDbQIuv2Sui6Y1f8A3/7RldSe1u4s=";
            modulePath = "github.com/openziti/ziti";
          };
          ziti_2 = final.callPackage ./pkgs/ziti {
            buildGo126Module = zitiBuildGo126Module;
          };
          ziti = final.ziti_2;
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
          inherit (pkgs)
            ziti
            ziti_1
            ziti_2
            ziti-edge-tunnel
            ;
          default = pkgs.ziti;
        }
      );

      checks = forAllSystems (
        system:
        let
          pkgs = mkPkgs system;
        in
        {
          ziti-v2-default = pkgs.runCommand "ziti-v2-default-check" { } ''
            test "${pkgs.ziti.version}" = "${pkgs.ziti_2.version}"
            case "${pkgs.ziti_1.version}" in
              1.*) ;;
              *) exit 1 ;;
            esac
            ${pkgs.ziti}/bin/ziti version | ${pkgs.gnugrep}/bin/grep -F "v${pkgs.ziti.version}"
            touch $out
          '';
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
