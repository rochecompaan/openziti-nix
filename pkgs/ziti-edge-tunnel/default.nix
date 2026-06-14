{
  lib,
  stdenv,
  fetchFromGitHub,
  cmake,
  json_c,
  libsodium,
  libpcap,
  libuv,
  llhttp,
  openssl,
  pkg-config,
  protobufc,
  stc,
  systemd,
  versionCheckHook,
  zlib,
}:

let
  inherit (lib) cmakeBool cmakeFeature;

  ziti_sdk_src = fetchFromGitHub {
    owner = "openziti";
    repo = "ziti-sdk-c";
    tag = "1.15.0";
    hash = "sha256-o1Hcrqz+e2vJZjnPxIAgy5xKwu+M24o/Knh99dwTR3I=";
  };
  lwip_src = fetchFromGitHub {
    owner = "lwip-tcpip";
    repo = "lwip";
    rev = "STABLE-2_2_1_RELEASE";
    hash = "sha256-8TYbUgHNv9SV3l203WVfbwDEHFonDAQqdykiX9OoM34=";
  };
  lwip_contrib_src = fetchFromGitHub {
    owner = "netfoundry";
    repo = "lwip-contrib";
    rev = "STABLE-2_1_0_RELEASE";
    hash = "sha256-Ypn/QfkiTGoKLCQ7SXozk4D/QIdo4lyza4yq3tAoP/0=";
  };
  subcommand_c_src = fetchFromGitHub {
    owner = "openziti";
    repo = "subcommands.c";
    rev = "87350797774530b6ba9c00017f0f53dd57e6c38e";
    hash = "sha256-Gz0/b9jcC1I0fmguSMkV0xiqKWq7vzUVT0Bd1F4iqkA=";
  };
  tlsuv_src = fetchFromGitHub {
    owner = "openziti";
    repo = "tlsuv";
    rev = "v0.41.1";
    hash = "sha256-mT1K8OpwE+brdEc6ik8jMhEsXGuEh5nqfY3urx7IQiA=";
  };
in
stdenv.mkDerivation (finalAttrs: {
  pname = "ziti-edge-tunnel";
  version = "1.15.1";

  src = fetchFromGitHub {
    owner = "openziti";
    repo = "ziti-tunnel-sdk-c";
    rev = "v${finalAttrs.version}";
    hash = "sha256-ZSTurUxd5tsnK/cCEynKLjSoaJUCOJQNLZ9RE5Mf3oU=";
  };

  postPatch = ''
    # Workaround for broken llhttp package
    mkdir -p patched-cmake
    cp -r ${lib.getDev llhttp}/lib/cmake/llhttp patched-cmake/
    chmod -R u+w patched-cmake

    llhttpCmakeFiles=$(grep -rl 'set(_IMPORT_PREFIX "${llhttp}")' patched-cmake/llhttp || true)
    if [ -z "$llhttpCmakeFiles" ]; then
      echo "could not find llhttp CMake import prefix to patch" >&2
      find patched-cmake/llhttp -maxdepth 1 -type f -print >&2
      exit 1
    fi
    substituteInPlace $llhttpCmakeFiles \
      --replace-fail 'set(_IMPORT_PREFIX "${llhttp}")' 'set(_IMPORT_PREFIX "${lib.getDev llhttp}")'

    # Patch hardcoded paths to systemd tools
    substituteInPlace programs/ziti-edge-tunnel/netif_driver/linux/resolvers.h \
      --replace-fail '"/usr/bin/busctl"' '"${systemd}/bin/busctl"' \
      --replace-fail '"/usr/bin/resolvectl"' '"${systemd}/bin/resolvectl"' \
      --replace-fail '"/usr/bin/systemd-resolve"' '"${systemd}/bin/systemd-resolve"'
  '';

  preConfigure = ''
    # Prepend patched cmake to path
    export CMAKE_PREFIX_PATH=$(pwd)/patched-cmake''${CMAKE_PREFIX_PATH:+:}$CMAKE_PREFIX_PATH

    # Copy dependencies
    cp -r ${lwip_src} ./deps/lwip

    chmod -R +w ./deps/
  '';

  cmakeFlags = [
    (cmakeBool "ENABLE_VCPKG" false)
    (cmakeBool "DISABLE_SEMVER_VERIFICATION" true)
    (cmakeBool "DISABLE_LIBSYSTEMD_FEATURE" true) # Disable direct integration to use resolvectl fallback
    (cmakeFeature "ZITI_SDK_DIR" "${ziti_sdk_src}")
    (cmakeFeature "ZITI_SDK_VERSION" "1.15.0")
    # Ensure a concrete version is embedded; upstream library stringifies ZITI_VERSION
    (cmakeFeature "CMAKE_C_FLAGS" "-DZITI_VERSION=v${finalAttrs.version}")
    (cmakeFeature "CMAKE_CXX_FLAGS" "-DZITI_VERSION=v${finalAttrs.version}")
    (cmakeFeature "CMAKE_C_FLAGS" "-DGIT_VERSION=${finalAttrs.version}")
    (cmakeFeature "CMAKE_CXX_FLAGS" "-DGIT_VERSION=${finalAttrs.version}")
    (cmakeBool "FETCHCONTENT_FULLY_DISCONNECTED" true)
    (cmakeFeature "FETCHCONTENT_SOURCE_DIR_LWIP" "../../deps/lwip")
    (cmakeFeature "FETCHCONTENT_SOURCE_DIR_LWIP-CONTRIB" "${lwip_contrib_src}")
    (cmakeFeature "FETCHCONTENT_SOURCE_DIR_SUBCOMMAND" "${subcommand_c_src}")
    (cmakeFeature "FETCHCONTENT_SOURCE_DIR_TLSUV" "${tlsuv_src}")
    (cmakeFeature "DOXYGEN_OUTPUT_DIR" "/tmp/doxygen")
    (cmakeFeature "CMAKE_BUILD_TYPE" "release")
  ];

  nativeBuildInputs = [
    cmake
    pkg-config
  ];

  buildInputs = [
    json_c
    libsodium
    libpcap
    libuv
    llhttp
    openssl
    protobufc
    stc
    zlib
  ];

  runtimeDependencies = [
    systemd # For the resolvectl command at runtime
  ];

  doInstallCheck = true;
  nativeInstallCheckInputs = [ versionCheckHook ];
  versionCheckProgramArg = "version";

  meta = {
    description = "provides protocol translation and other common functions that are useful to Ziti Tunnelers";
    changelog = "https://github.com/openziti/ziti-tunnel-sdk-c/releases/tag/v${finalAttrs.version}";
    homepage = "https://openziti.io/";
    maintainers = [
      {
        name = "Roché Compaan";
        email = "roche@sixfeetup.com";
        github = "rochecompaan";
      }
    ];
    license = lib.licenses.asl20;
    mainProgram = "ziti-edge-tunnel";
  };
})
