#!/usr/bin/env bash
set -euo pipefail

system=${SYSTEM:-$(nix eval --impure --raw --expr builtins.currentSystem)}

ziti_version=$(nix eval --raw ".#packages.${system}.ziti.version")
ziti_2_version=$(nix eval --raw ".#packages.${system}.ziti_2.version")
ziti_1_version=$(nix eval --raw ".#packages.${system}.ziti_1.version")
default_name=$(nix eval --raw ".#packages.${system}.default.pname")
default_version=$(nix eval --raw ".#packages.${system}.default.version")

[[ ${ziti_version} == 2.* ]]
[[ ${ziti_2_version} == "${ziti_version}" ]]
[[ ${ziti_1_version} == 1.* ]]
[[ ${default_name} == "ziti" ]]
[[ ${default_version} == "${ziti_2_version}" ]]

store_path=$(nix build --print-out-paths --no-link ".#packages.${system}.ziti")
version_output=$("${store_path}/bin/ziti" version)
[[ ${version_output} == *"v${ziti_version}"* ]]
