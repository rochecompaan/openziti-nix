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
    hash = "sha256-jpIVCXKYHt6pxrpRQ+cbMKo7ud3ChnMdePuVFSygjjg=";
  };

  vendorHash = "sha256-hTewmgC96WlsaFBjZDbvSIrlvCvDdYhSPG7vgFQsLkk=";

  subPackages = [ "ziti" ];

  env.CGO_ENABLED = 1;

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

