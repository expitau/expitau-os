# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).
{ inputs, self, ... }: {
  nixosConfigurations.expitau-nixos = let nixpkgs = inputs.nixpkgs; in nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        specialArgs = { inherit inputs; };
        modules = [
          self.nixosModules.main
          self.nixosModules.android
          self.nixosModules.grapheneos
          self.nixosModules.hardware
          # self.nixosModules.keysnek
          self.nixosModules.lxc
          # self.nixosModules.virtualisation
          inputs.home-manager.nixosModules.default
        ];
      };
}
