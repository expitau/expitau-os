{ pkgs, lib }:

pkgs.stdenv.mkDerivation {
  pname = "desktop-head-unit";
  version = "local";

  src = ./src;

  nativeBuildInputs = [
    pkgs.autoPatchelfHook
    pkgs.makeWrapper
    pkgs.pkg-config
  ];

  buildInputs = [
    pkgs.zlib
    pkgs.gcc.cc.libgcc

    pkgs.llvmPackages.libcxx
    pkgs.alsa-lib
    pkgs.libusb1

    pkgs.SDL2
    pkgs.libGL
    pkgs.libGLU
    pkgs.mesa
    pkgs.libX11
    pkgs.libXrandr
    pkgs.libXcursor
    pkgs.libXi
    pkgs.libXrender
    pkgs.libXext
    pkgs.libdrm
    pkgs.libgbm
    pkgs.wayland
    pkgs.libxkbcommon
  ];

  installPhase = ''
    runHook preInstall

    mkdir -p $out/share
    mkdir -p $out/bin

    # Copy full server folder

    cp -r --no-preserve=mode $src/auto $out/share/

    chmod +x $out/share/auto/desktop-head-unit

    makeWrapper \
      $out/share/auto/desktop-head-unit \
      $out/bin/desktop-head-unit \
      --set SDL_VIDEODRIVER x11 \
      --set SDL_RENDER_DRIVER opengl \
      --prefix LD_LIBRARY_PATH : ${
        lib.makeLibraryPath [
          pkgs.libX11
          pkgs.libXext
          pkgs.libXrandr
          pkgs.libXcursor
          pkgs.libXi
          pkgs.libXrender
          pkgs.libdrm
          pkgs.libgbm
          pkgs.wayland
          pkgs.libxkbcommon
          pkgs.libGL
          pkgs.mesa
        ]
      }

    runHook postInstall
  '';

  meta = {
    description = "Android Auto Desktop Head Unit";
    homepage = "https://developer.android.com/training/cars/testing/dhu";
    platforms = [ "x86_64-linux" ];
    mainProgram = "desktop-head-unit";
  };
}
