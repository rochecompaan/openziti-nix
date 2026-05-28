{
  lib,
  buildGo126Module,
  fetchFromGitHub,
  versionCheckHook,
  version ? "2.0.0",
  srcHash ? "sha256-JFEj4AYfyJl4OWCgFL2Vb+/YYig5rNnTmqmd5Xr4LUY=",
  vendorHash ? "sha256-6U9iQrU1SESdhY2CQz2ZMcA4MknfCc4Ah6v6JClJ78c=",
  modulePath ? "github.com/openziti/ziti/v2",
}:

buildGo126Module (finalAttrs: {
  pname = "ziti";
  inherit version;

  src = fetchFromGitHub {
    owner = "openziti";
    repo = "ziti";
    tag = "v${finalAttrs.version}";
    hash = srcHash;
  };

  inherit vendorHash;

  subPackages = [
    "ziti"
    "controller"
    "router"
  ];

  ldflags = [
    "-s"
    "-w"
    "-X ${modulePath}/common/version.Version=v${finalAttrs.version}"
    "-X ${modulePath}/common/version.Revision=v${finalAttrs.src.rev}"
    "-X ${modulePath}/common/version.BuildDate=1970-01-01T00:00:00Z"
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
