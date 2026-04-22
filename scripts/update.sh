#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd "$(dirname "$0")/.." && pwd)
cd "$repo_root"

echo "Resolving latest ziti release..."
ziti_version=$(curl -fsSL https://api.github.com/repos/openziti/ziti/releases/latest | python3 -c 'import json, sys; print(json.load(sys.stdin)["tag_name"].removeprefix("v"))')

echo "Running nix-update for ziti ${ziti_version}..."
nix run nixpkgs#nix-update -- --flake ziti --version "${ziti_version}" --use-github-releases --commit --build

echo "Running custom update for ziti-edge-tunnel..."
./scripts/update-ziti-edge-tunnel.py --commit --build
