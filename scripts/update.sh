#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd "$(dirname "$0")/.." && pwd)
cd "$repo_root"

echo "Running nix-update for ziti..."
nix run nixpkgs#nix-update -- --flake ziti --version stable --use-github-releases --commit --build

echo "Running custom update for ziti-edge-tunnel..."
./scripts/update-ziti-edge-tunnel.py --commit --build
