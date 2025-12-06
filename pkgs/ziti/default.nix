{
  lib,
  buildGoModule,
  fetchFromGitHub,
  ...
}:

buildGoModule rec {
  pname = "ziti";
  version = "1.8.0-pre3";

  src = fetchFromGitHub {
    owner = "openziti";
    repo = "ziti";
    rev = "v${version}";
    hash = "sha256-7z/1CNBfx5ivo7aZ6nmpMJPtn5OFbUHZn/CwR9Nv2kA=";
  };

  vendorHash = "sha256-K7odByiYhKwJKYQbVDhs76V0cI80ACed2YXgcA0vMZw=";

  subPackages = [ "ziti" ];

  env.CGO_ENABLED = 1;
  # Recreate vendor/ from modules to avoid upstream vendored inconsistencies
  proxyVendor = true;

  ldflags = [
    "-s"
    "-w"
    "-X github.com/openziti/ziti/common/version.Version=${version}"
    "-X github.com/openziti/ziti/common/version.Branch=tags/v${version}"
  ];

  meta = {
    description = "OpenZiti CLI (ziti)";
    homepage = "https://github.com/openziti/ziti";
    license = lib.licenses.asl20;
    mainProgram = "ziti";
    platforms = lib.platforms.unix;
  };
}
