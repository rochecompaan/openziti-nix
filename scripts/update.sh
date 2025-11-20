#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd "$(dirname "$0")/.." && pwd)
cd "$repo_root"

echo "Running nix-update for ziti-cli..."
nix run nixpkgs#nix-update -- --flake .#ziti-cli --commit --build

echo "Running nix-update for ziti-edge-tunnel..."
nix run nixpkgs#nix-update -- --flake .#ziti-edge-tunnel --commit --build
