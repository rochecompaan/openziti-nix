{
  lib,
  stdenv,
  fetchFromGitHub,
}:

stdenv.mkDerivation (finalAttrs: {
  pname = "stc";
  version = "5.0";

  outputs = [
    "out"
    "dev"
    "doc"
  ];

  src = fetchFromGitHub {
    owner = "stclib";
    repo = "STC";
    tag = "v${finalAttrs.version}";
    hash = "sha256-JiFyJN+hAbzTHqim1i6TJFmKfHlnOfP3yDLCZDE7uqo=";
  };

  dontBuild = true;

  installPhase = ''
    runHook preInstall

    mkdir -p "$out/share/licenses/${finalAttrs.pname}"
    mkdir -p "$dev/include"
    mkdir -p "$dev/lib/pkgconfig"
    mkdir -p "$doc/share/doc/${finalAttrs.pname}"

    cp LICENSE "$out/share/licenses/${finalAttrs.pname}/"
    cp README.md "$doc/share/doc/${finalAttrs.pname}/"
    cp -r include/. "$dev/include/"
    cp -r docs/. "$doc/share/doc/${finalAttrs.pname}/"

    cat > "$dev/lib/pkgconfig/stc.pc" <<EOF
    prefix=$dev
    exec_prefix=$dev
    includedir=$dev/include

    Name: stc
    Description: C99 container library with generic and type-safe data structures
    Version: ${finalAttrs.version}
    Cflags: -I$dev/include
    Libs:
    EOF

    runHook postInstall
  '';

  meta = {
    description = "C99 container library with generic and type-safe data structures";
    homepage = "https://github.com/stclib/STC";
    changelog = "https://github.com/stclib/STC/releases/tag/v${finalAttrs.version}";
    license = lib.licenses.mit;
    platforms = lib.platforms.all;
  };
})
