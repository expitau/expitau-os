{
  description = "Android Auto Desktop Head Unit";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs =
    { self, nixpkgs }:
    let
      system = "x86_64-linux";
      pkgs = import nixpkgs { inherit system; };
    in
    {
      packages.${system}.desktop-head-unit = pkgs.callPackage ./default.nix { };

      apps.${system}.desktop-head-unit = {
        type = "app";
        program = "${self.packages.${system}.desktop-head-unit}/bin/desktop-head-unit";
      };

      defaultPackage.${system} = self.packages.${system}.desktop-head-unit;
    };
}
