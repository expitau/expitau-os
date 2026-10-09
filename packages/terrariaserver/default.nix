{ pkgs, lib }:

pkgs.stdenv.mkDerivation {
  pname = "terraria-server";
  version = "local";

  src = pkgs.fetchzip {
    url = "https://terraria.org/api/download/pc-dedicated-server/terraria-server-1454.zip";
    sha256 = "sha256-0yxPGpF86onS49M51tmFEvrs79BWykr3Z8VznVsfsI8=";
    stripRoot = true;
  };

  nativeBuildInputs = [
    pkgs.autoPatchelfHook
    pkgs.makeWrapper
  ];

  buildInputs = [
    pkgs.zlib
    pkgs.gcc.cc.libgcc
  ];

  installPhase = ''
    runHook preInstall

    mkdir -p $out/share/terraria
    mkdir -p $out/bin

    # Copy full server folder

    cp -r --no-preserve=mode $(find $src -type d -iname Linux) $out/share/terraria/

    # Remove client-only SDL libs
    rm -rf $out/share/terraria/Linux/lib64

    chmod +x $out/share/terraria/Linux/TerrariaServer.bin.x86_64

    # Wrap server with Mono in PATH
    makeWrapper \
      $out/share/terraria/Linux/TerrariaServer.bin.x86_64 \
      $out/bin/TerrariaServer \
      --prefix PATH : ${lib.makeBinPath [ pkgs.mono ]}

    runHook postInstall
  '';

  meta = {
    description = "Terraria dedicated server (headless, Mono)";
    homepage = "https://terraria.org";
    platforms = [ "x86_64-linux" ];
    mainProgram = "TerrariaServer";
  };
}
