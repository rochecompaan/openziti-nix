{
  lib,
  buildGoModule,
  fetchFromGitHub,
  ...
}:

buildGoModule rec {
  pname = "ziti";
  version = "1.7.2";

  src = fetchFromGitHub {
    owner = "openziti";
    repo = "ziti";
    rev = "v${version}";
    hash = "sha256-P5adwgLPW2w4xMOd8x7BIVdPo7I9p/65WWo38i1znqI=";
  };

  vendorHash = "sha256-/j98NnMFFBhr9+XxHnBGQF0v8Qid6CMWWCjS//z1QFY=";

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

