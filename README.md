# openziti-nix

OpenZiti packages and NixOS modules for `ziti-cli` and `ziti-edge-tunnel`.

## Usage (as a flake input)

```nix
{
  inputs.openziti-nix.url = "github:rochecompaan/openziti-nix";

  outputs = { self, nixpkgs, openziti-nix, ... }: {
    nixosConfigurations.host = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        openziti-nix.nixosModules.withOverlays
        openziti-nix.nixosModules.ziti
        openziti-nix.nixosModules.ziti-edge-tunnel
        # or simply: openziti-nix.nixosModules.default
        ({ config, pkgs, ... }: {
          programs.ziti.enable = true;
          programs.ziti-edge-tunnel.enable = true;
          programs.ziti-edge-tunnel.tunnel.enable = true;
        })
      ];
    };
  };
}
```

### Overlay-only

```nix
nixpkgs.overlays = [ inputs.openziti-nix.overlays.default ];
# Then use pkgs.ziti-cli and pkgs.ziti-edge-tunnel
```

### Packages

```shell
nix build github:rochecompaan/openziti-nix#ziti-cli
nix build github:rochecompaan/openziti-nix#ziti-edge-tunnel
```

## Layout

- pkgs/ziti-cli: Go CLI build
- pkgs/ziti-edge-tunnel: CMake build of ziti-edge-tunnel
- modules/ziti: NixOS module for CLI
- modules/ziti-edge-tunnel: NixOS module for service
- flake.nix: overlays, packages, modules
