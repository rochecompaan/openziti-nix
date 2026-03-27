#!/usr/bin/env python3
import argparse
import json
import os
import re
import subprocess
import sys
import tarfile
import tempfile
import urllib.error
import urllib.parse
import urllib.request
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parent.parent
PACKAGE_FILE = REPO_ROOT / "pkgs" / "ziti-edge-tunnel" / "default.nix"
USER_AGENT = "openziti-nix-updater/1"


def run(cmd: list[str], cwd: Path | None = None) -> str:
    proc = subprocess.run(
        cmd,
        cwd=str(cwd) if cwd else None,
        check=True,
        text=True,
        capture_output=True,
    )
    return proc.stdout.strip()


def github_request(url: str) -> bytes:
    headers = {
        "Accept": "application/vnd.github+json",
        "User-Agent": USER_AGENT,
    }
    token = os.environ.get("GITHUB_TOKEN")
    if token:
        headers["Authorization"] = f"Bearer {token}"
    req = urllib.request.Request(url, headers=headers)
    with urllib.request.urlopen(req) as resp:
        return resp.read()


def github_api(path: str) -> dict:
    data = github_request(f"https://api.github.com{path}")
    return json.loads(data)


def latest_stable_release(owner: str, repo: str) -> str:
    release = github_api(f"/repos/{owner}/{repo}/releases/latest")
    tag = release["tag_name"]
    return tag[1:] if tag.startswith("v") else tag


def download_tarball(url: str, tmpdir: Path) -> Path:
    tmpdir.mkdir(parents=True, exist_ok=True)
    archive_path = tmpdir / "src.tar.gz"
    headers = {"User-Agent": USER_AGENT}
    token = os.environ.get("GITHUB_TOKEN")
    if token:
        headers["Authorization"] = f"Bearer {token}"
    req = urllib.request.Request(url, headers=headers)
    with urllib.request.urlopen(req) as resp, archive_path.open("wb") as fh:
        fh.write(resp.read())
    with tarfile.open(archive_path) as tar:
        tar.extractall(tmpdir, filter="data")
    roots = [p for p in tmpdir.iterdir() if p.is_dir()]
    if len(roots) != 1:
        raise RuntimeError(f"expected one extracted root for {url}, got {roots}")
    return roots[0]


def fetchcontent_tag(text: str, name: str) -> str:
    pattern = re.compile(
        rf"FetchContent_Declare\(\s*{re.escape(name)}\s*(.*?)\)",
        re.S,
    )
    match = pattern.search(text)
    if not match:
        raise RuntimeError(f"missing FetchContent_Declare for {name}")
    block = match.group(1)
    tag_match = re.search(r"GIT_TAG\s+([^\s)]+)", block)
    if not tag_match:
        raise RuntimeError(f"missing GIT_TAG for {name}")
    return tag_match.group(1).strip().strip('"')


def cmake_set(text: str, variable: str) -> str:
    match = re.search(
        rf'set\(\s*{re.escape(variable)}\s+"([^"]+)"',
        text,
    )
    if not match:
        raise RuntimeError(f"missing set({variable} ...)")
    return match.group(1)


def is_movable_ref(ref: str) -> bool:
    if re.fullmatch(r"[0-9a-f]{40}", ref):
        return False
    if ref.startswith("STABLE-"):
        return False
    if re.fullmatch(r"v?\d+(?:\.\d+)+(?:[-._][A-Za-z0-9]+)?", ref):
        return False
    return True


def resolve_ref(owner: str, repo: str, ref: str) -> str:
    if not is_movable_ref(ref):
        return ref
    commit = github_api(f"/repos/{owner}/{repo}/commits/{urllib.parse.quote(ref, safe='')}")
    return commit["sha"]


def archive_url(owner: str, repo: str, ref_kind: str, ref: str) -> str:
    if ref_kind == "tag":
        return f"https://github.com/{owner}/{repo}/archive/refs/tags/{ref}.tar.gz"
    return f"https://github.com/{owner}/{repo}/archive/{ref}.tar.gz"


def prefetch_sri(url: str) -> str:
    result = run(
        [
            "nix",
            "store",
            "prefetch-file",
            "--json",
            "--extra-experimental-features",
            "nix-command",
            "--unpack",
            url,
        ]
    )
    return json.loads(result)["hash"]


def replace_one(text: str, pattern: str, replacement: str) -> str:
    updated, count = re.subn(pattern, replacement, text, count=1, flags=re.S | re.M)
    if count != 1:
        raise RuntimeError(f"expected one replacement for pattern: {pattern}")
    return updated


def update_fetch_block(text: str, block_name: str, attr_name: str, value: str, hash_value: str) -> str:
    pattern = (
        rf'({re.escape(block_name)}\s*=\s*fetchFromGitHub\s*\{{.*?'
        rf'{re.escape(attr_name)}\s*=\s*")[^"]+(";\s*hash\s*=\s*")[^"]+(";\s*\}};)'
    )
    replacement = rf"\g<1>{value}\2{hash_value}\3"
    return replace_one(text, pattern, replacement)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--version", help="Target ziti-edge-tunnel version; defaults to latest stable release")
    parser.add_argument("--build", action="store_true", help="Build the updated package")
    parser.add_argument("--commit", action="store_true", help="Commit the updated package file")
    args = parser.parse_args()

    current_text = PACKAGE_FILE.read_text()
    current_version_match = re.search(r'^\s*version = "([^"]+)";', current_text, re.M)
    if not current_version_match:
        raise RuntimeError("could not determine current ziti-edge-tunnel version")
    current_version = current_version_match.group(1)
    target_version = args.version or latest_stable_release("openziti", "ziti-tunnel-sdk-c")

    with tempfile.TemporaryDirectory() as tmp:
        tmpdir = Path(tmp)
        tunnel_root = download_tarball(
            archive_url("openziti", "ziti-tunnel-sdk-c", "tag", f"v{target_version}"),
            tmpdir / "tunnel",
        )
        tunnel_cmake = (tunnel_root / "CMakeLists.txt").read_text()
        tunnel_deps = (tunnel_root / "deps" / "CMakeLists.txt").read_text()
        programs_cmake = (tunnel_root / "programs" / "CMakeLists.txt").read_text()

        ziti_sdk_version = cmake_set(tunnel_cmake, "ZITI_SDK_VERSION")
        lwip_ref = fetchcontent_tag(tunnel_deps, "lwip")
        lwip_contrib_ref = fetchcontent_tag(tunnel_deps, "lwip-contrib")
        subcommand_ref = fetchcontent_tag(programs_cmake, "subcommand")
        resolved_subcommand_ref = resolve_ref("openziti", "subcommands.c", subcommand_ref)

        sdk_root = download_tarball(
            archive_url("openziti", "ziti-sdk-c", "tag", ziti_sdk_version),
            tmpdir / "sdk",
        )
        sdk_cmake = (sdk_root / "CMakeLists.txt").read_text()
        tlsuv_ref = cmake_set(sdk_cmake, "tlsuv_VERSION")

        updates = {
            "main_src": {
                "owner": "openziti",
                "repo": "ziti-tunnel-sdk-c",
                "ref_kind": "tag",
                "ref": f"v{target_version}",
            },
            "ziti_sdk_src": {
                "owner": "openziti",
                "repo": "ziti-sdk-c",
                "ref_kind": "tag",
                "ref": ziti_sdk_version,
            },
            "lwip_src": {
                "owner": "lwip-tcpip",
                "repo": "lwip",
                "ref_kind": "rev",
                "ref": lwip_ref,
            },
            "lwip_contrib_src": {
                "owner": "netfoundry",
                "repo": "lwip-contrib",
                "ref_kind": "rev",
                "ref": lwip_contrib_ref,
            },
            "subcommand_c_src": {
                "owner": "openziti",
                "repo": "subcommands.c",
                "ref_kind": "rev",
                "ref": resolved_subcommand_ref,
            },
            "tlsuv_src": {
                "owner": "openziti",
                "repo": "tlsuv",
                "ref_kind": "rev",
                "ref": tlsuv_ref,
            },
        }

        for dep in updates.values():
            dep["hash"] = prefetch_sri(archive_url(dep["owner"], dep["repo"], dep["ref_kind"], dep["ref"]))

    updated = current_text
    updated = replace_one(
        updated,
        r'(^\s*version = ")[^"]+(";\s*$)',
        rf'\g<1>{target_version}\2',
    )
    updated = update_fetch_block(
        updated,
        "src",
        "rev",
        f'v${{finalAttrs.version}}',
        updates["main_src"]["hash"],
    )
    updated = update_fetch_block(
        updated,
        "ziti_sdk_src",
        "tag",
        updates["ziti_sdk_src"]["ref"],
        updates["ziti_sdk_src"]["hash"],
    )
    updated = update_fetch_block(
        updated,
        "lwip_src",
        "rev",
        updates["lwip_src"]["ref"],
        updates["lwip_src"]["hash"],
    )
    updated = update_fetch_block(
        updated,
        "lwip_contrib_src",
        "rev",
        updates["lwip_contrib_src"]["ref"],
        updates["lwip_contrib_src"]["hash"],
    )
    updated = update_fetch_block(
        updated,
        "subcommand_c_src",
        "rev",
        updates["subcommand_c_src"]["ref"],
        updates["subcommand_c_src"]["hash"],
    )
    updated = update_fetch_block(
        updated,
        "tlsuv_src",
        "rev",
        updates["tlsuv_src"]["ref"],
        updates["tlsuv_src"]["hash"],
    )
    updated = replace_one(
        updated,
        r'((?:cmakeFeature "ZITI_SDK_VERSION" "))[^\"]+(")',
        rf'\g<1>{ziti_sdk_version}\2',
    )

    if updated == current_text:
        print("ziti-edge-tunnel is already aligned with upstream dependencies")
    else:
        PACKAGE_FILE.write_text(updated)
        print(f"Updated {PACKAGE_FILE}")

    if args.build:
        subprocess.run(
            ["nix", "build", "-L", ".#ziti-edge-tunnel"],
            cwd=REPO_ROOT,
            check=True,
        )

    if args.commit and updated != current_text:
        if current_version == target_version:
            message = f"ziti-edge-tunnel: sync upstream deps for {target_version}"
        else:
            message = f"ziti-edge-tunnel: {current_version} -> {target_version}"
        subprocess.run(["git", "add", str(PACKAGE_FILE)], cwd=REPO_ROOT, check=True)
        subprocess.run(["git", "commit", "-m", message], cwd=REPO_ROOT, check=True)

    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except urllib.error.HTTPError as exc:
        print(f"HTTP error: {exc}", file=sys.stderr)
        raise
