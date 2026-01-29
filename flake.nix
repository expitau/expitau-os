{
  description = "System Configuration";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    { nixpkgs, ... }@inputs:
    let
      fileTree = path: builtins.concatLists (builtins.attrValues (builtins.mapAttrs (name: value: if value == "directory" then fileTree "${path}/${name}" else [ "${path}/${name}" ]) (builtins.readDir path)));
      self = builtins.foldl' nixpkgs.lib.recursiveUpdate { } (
        map (path: (import path) { inherit inputs self; }) (
          map (name: "${./modules}/${name}") (
            nixpkgs.lib.filter (name: nixpkgs.lib.hasSuffix ".nix" name) (
              fileTree ./modules
            )
          )
        )
      );

      walk = self: v:
        if builtins.isFunction v then
          v self
        else if builtins.isAttrs v then
          builtins.mapAttrs (_: child: walk self child) v
        else
          v;
    in
    self;
}
