{
  description = "Terraria dedicated server (headless flake)";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs =
    { self, nixpkgs }:
    let
      system = "x86_64-linux";
      pkgs = import nixpkgs { inherit system; };
    in
    {
      packages.${system}.terrariaserver = pkgs.callPackage ./default.nix { };

      apps.${system}.terrariaserver = {
        type = "app";
        program = "${self.packages.${system}.terrariaserver}/bin/TerrariaServer";
      };

      defaultPackage.${system} = self.packages.${system}.terrariaserver;
    };
}
