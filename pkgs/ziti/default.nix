{
  lib,
  buildGo126Module,
  fetchFromGitHub,
  versionCheckHook,
}:

buildGo126Module (finalAttrs: {
  pname = "ziti";
  version = "1.5.13";

  src = fetchFromGitHub {
    owner = "openziti";
    repo = "ziti";
    tag = "v${finalAttrs.version}";
    hash = "sha256-x9AinhYM3v4XS9iPLgUltsh8w2Rlkgd0qZy3br/YsMo=";
  };

  vendorHash = "sha256-8zap+KSNZjgxCWH94vOzmzlVHr2jikQ7gUlf633j2WI=";

  subPackages = [
    "ziti"
    "controller"
    "router"
  ];

  ldflags = [
    "-s"
    "-w"
    "-X github.com/openziti/ziti/common/version.Version=v${finalAttrs.version}"
    "-X github.com/openziti/ziti/common/version.Revision=v${finalAttrs.src.rev}"
    "-X github.com/openziti/ziti/common/version.BuildDate=1970-01-01T00:00:00Z"
  ];

  doInstallCheck = true;
  nativeInstallCheckInputs = [ versionCheckHook ];
  versionCheckProgramArg = "version";

  meta = {
    description = "CLI for working with a Ziti deployment";
    changelog = "https://github.com/openziti/ziti/releases/tag/v${finalAttrs.version}";
    homepage = "https://openziti.io/";
    license = lib.licenses.asl20;
    maintainers = [
      {
        name = "Roché Compaan";
        email = "roche@sixfeetup.com";
        github = "rochecompaan";
      }
    ];
    mainProgram = "ziti";
  };
})
