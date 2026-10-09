{
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs =
    { self, nixpkgs }:
    let
      system = "x86_64-linux";
      pkgs = import nixpkgs { inherit system; };
      src = pkgs.fetchFromGitHub {
        owner = "gvolpe";
        repo = "dconf2nix";
        rev = "dd1dacf17ed97be48d459e6c72524872fd0e6ab6";
        hash = "sha256-P2jxSiq5aypnhk+J0W5dOqsoyjIX9l8Uz2xeRXBuSCc=";
      };
    in
    {
      packages.${system}.dconf2nix = pkgs.haskellPackages.callCabal2nix "dconf2nix" src { };
    };
}
