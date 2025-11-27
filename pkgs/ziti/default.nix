{
  lib,
  buildGoModule,
  fetchFromGitHub,
  ...
}:

buildGoModule rec {
  pname = "ziti";
  version = "1.6.9";

  src = fetchFromGitHub {
    owner = "openziti";
    repo = "ziti";
    rev = "v${version}";
    hash = "sha256-Thk0h67qUL72xewbpjujv7mUYzpSAWJXMk6QmPFGqVg=";
  };

  vendorHash = "sha256-S0Gsj35weIrvJq2eHaKEUWalocGuTJT5u3TbzU0vTHc=";

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
