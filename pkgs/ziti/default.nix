{
  lib,
  buildGoModule,
  fetchFromGitHub,
  ...
}:

buildGoModule rec {
  pname = "ziti";
  version = "1.5.9";

  src = fetchFromGitHub {
    owner = "openziti";
    repo = "ziti";
    rev = "v${version}";
    hash = "sha256-jpIVCXKYHt6pxrpRQ+cbMKo7ud3ChnMdePuVFSygjjg=";
  };

  vendorHash = "sha256-78zdG6FT29H66HFJSperhSwQyOt6VJdhw5eHAv/fGyw=";

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
