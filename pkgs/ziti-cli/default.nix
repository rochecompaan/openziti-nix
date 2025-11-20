{
  lib,
  buildGoModule,
  fetchFromGitHub,
  ...
}:

buildGoModule rec {
  pname = "ziti";
  version = "1.6.8";

  src = fetchFromGitHub {
    owner = "openziti";
    repo = "ziti";
    rev = "v${version}";
    hash = "sha256-J655F9lFRLL1LdNOelRpipiIb2u2HEvVSehvPpRYRUw=";
  };

  vendorHash = "sha256-CD/7WfRf6MEo7V9akA1/gP7b8wUr+2QCjbn6yIJYBYM=";

  # Build the CLI; router/controller are subcommands of `ziti`
  subPackages = [ "ziti" ];

  env.CGO_ENABLED = 1;

  ldflags = [
    "-s"
    "-w"
    "-X github.com/openziti/ziti/common/version.Version=${version}"
  ];

  meta = {
    description = "OpenZiti CLI and Router";
    homepage = "https://github.com/openziti/ziti";
    license = lib.licenses.asl20;
    mainProgram = "ziti";
    platforms = lib.platforms.unix;
  };
}
