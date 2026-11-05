{ lib, stdenvNoCC, fetchurl, buildFHSEnv, writeShellScript, pkgs }:
let
  version = "3.6.23";
  vendor = stdenvNoCC.mkDerivation {
    pname = "blender-vendor";
    inherit version;
    src = fetchurl {
      urls = [
        "https://mirror.blender.org/release/Blender3.6/blender-${version}-linux-x64.tar.xz"
        "https://mirrors.dotsrc.org/blender/release/Blender3.6/blender-${version}-linux-x64.tar.xz"
      ];
      sha256 = "0e9a18af4d0060b825e9617e24a775f759e0f9f67271c062f3d53a539030af00";
    };
    dontBuild = true;
    dontFixup = true;
    installPhase = ''
      mkdir -p "$out"
      cp -a . "$out/"
    '';
  };
in buildFHSEnv {
  pname = "blender";
  inherit version;
  targetPkgs = p: with p; [
    stdenv.cc.cc.lib alsa-lib dbus libGL libGLU libx11 libxxf86vm
    libxfixes libxrender libxi libxext libsm libice libxkbcommon
    libxcursor libxrandr wayland libdecor zlib
  ];
  runScript = writeShellScript "blender-launch" ''
    # Blender's Wayland/EGL context fails on this VirtualBox graphics stack.
    export WAYLAND_DISPLAY=0
    exec ${vendor}/blender "$@"
  '';
  extraInstallCommands = ''
    mkdir -p "$out/share/applications" "$out/share/icons/hicolor/scalable/apps"
    cp ${vendor}/blender.desktop "$out/share/applications/blender.desktop"
    cp ${vendor}/blender.svg "$out/share/icons/hicolor/scalable/apps/blender.svg"
  '';
  passthru = { inherit vendor; };
  meta = {
    description = "Blender 3.6 LTS, compatible with VirtualBox OpenGL";
    homepage = "https://www.blender.org/";
    license = lib.licenses.gpl3Plus;
    platforms = [ "x86_64-linux" ];
    mainProgram = "blender";
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
  };
}
