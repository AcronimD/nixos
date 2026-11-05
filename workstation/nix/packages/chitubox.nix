{ lib, stdenvNoCC, fetchurl, buildFHSEnv, writeShellScript, makeDesktopItem, python3, _7zz, pkgs }:
let
  version = "2.3.1";
  vendor = stdenvNoCC.mkDerivation {
    pname = "chitubox-basic-vendor";
    inherit version;
    src = fetchurl {
      url = "https://download.chitubox.com/17839/v${version}/CHITUBOX_Basic_linux_Installer_${version}";
      hash = "sha256-OX4FjeU7aS4dthZXkp4c6fiPCQy5c8jCD95bDU36Ymg=";
    };
    nativeBuildInputs = [ python3 _7zz ];
    dontUnpack = true;
    dontBuild = true;
    dontFixup = true; # Preserve vendor binaries and signed Anycubic plugins.
    installPhase = ''
      python3 ${./extract-qtifw.py} "$src" archives
      test "$(find archives -name '*.7z' | wc -l)" = 7
      mkdir -p "$out"
      for archive in archives/*.7z; do
        7zz x -y -o"$out" "$archive" > /dev/null
      done
      test -x "$out/bin/CHITUBOX_Basic"
      test -f "$out/CHITUBOX_Basic.sh"
    '';
  };
  desktop = makeDesktopItem {
    name = "chitubox";
    desktopName = "CHITUBOX Basic";
    genericName = "Resin 3D printing slicer";
    exec = "chitubox %F";
    icon = "chitubox";
    categories = [ "Graphics" "3DGraphics" "Engineering" ];
    mimeTypes = [ "model/stl" "application/vnd.ms-3mfdocument" ];
    terminal = false;
  };
in buildFHSEnv {
  pname = "chitubox";
  inherit version;
  targetPkgs = p: with p; [
    stdenv.cc.cc.lib alsa-lib atk at-spi2-atk cairo cups dbus expat
    fontconfig freetype gdk-pixbuf glib gst_all_1.gstreamer gst_all_1.gst-plugins-base
    libGL libGLU libpulseaudio libx11 libxcb libxext libxi libxrender libxcursor
    libxcomposite libxdamage libxfixes libxrandr libxscrnsaver libxtst
    libxkbcommon libxkbfile libxcb-util libxcb-image libxcb-keysyms libxcb-cursor
    libxcb-render-util libxcb-wm libxshmfence libdrm libgbm nss nspr
    util-linux systemd zlib openssl krb5
  ];
  extraBuildCommands = ''
    mkdir -p "$out/usr/share/X11"
    ln -s ${pkgs.xkeyboard-config}/share/X11/xkb "$out/usr/share/X11/xkb"
  '';
  runScript = writeShellScript "chitubox-launch" ''
    unset QT_PLUGIN_PATH QT_QPA_PLATFORM_PLUGIN_PATH QML_IMPORT_PATH QML2_IMPORT_PATH
    export QT_QPA_PLATFORM=xcb
    export XKB_CONFIG_ROOT=${pkgs.xkeyboard-config}/share/X11/xkb
    # VirtualBox SVGA3D produces a white viewport with this vendor shader stack.
    # Keep normal GPU rendering on physical hosts; allow an explicit override.
    renderer="''${CHITUBOX_RENDERER:-auto}"
    if [ "$renderer" = software ] || {
      [ "$renderer" = auto ] &&
      [ "$(${pkgs.coreutils}/bin/cat /sys/class/dmi/id/product_name 2>/dev/null)" = VirtualBox ];
    }; then
      export LIBGL_ALWAYS_SOFTWARE=1
      export GALLIUM_DRIVER=llvmpipe
    fi
    cd "${vendor}"
    exec ${pkgs.bash}/bin/bash ./CHITUBOX_Basic.sh "$@"
  '';
  extraInstallCommands = ''
    mkdir -p "$out/share/applications" "$out/share/icons/hicolor/scalable/apps"
    cp ${desktop}/share/applications/chitubox.desktop "$out/share/applications/"
    cp ${./chitubox.svg} "$out/share/icons/hicolor/scalable/apps/chitubox.svg"
  '';
  passthru = { inherit vendor; };
  meta = {
    description = "CHITUBOX Basic resin printing slicer with intact vendor plugins";
    homepage = "https://www.chitubox.com/";
    license = lib.licenses.unfree;
    platforms = [ "x86_64-linux" ];
    mainProgram = "chitubox";
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
  };
}
