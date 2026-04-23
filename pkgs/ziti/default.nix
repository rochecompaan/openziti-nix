{
  lib,
  buildGo126Module,
  fetchFromGitHub,
  versionCheckHook,
}:

buildGo126Module (finalAttrs: {
  pname = "ziti";
  version = "1.6.15";

  src = fetchFromGitHub {
    owner = "openziti";
    repo = "ziti";
    tag = "v${finalAttrs.version}";
    hash = "sha256-Lvm7iWKDx3IYUsWTzrpuEaKSp0A/5zUGO+XxOJwzCkY=";
  };

  vendorHash = "sha256-nGOSIwyIYYN1lKMDbQIuv2Sui6Y1f8A3/7RldSe1u4s=";

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
