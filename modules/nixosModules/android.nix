{ inputs, self, ... }: {
  nixosModules.android = {
      config,
      pkgs,
      lib,
      ...
    }:
    {
      environment.systemPackages = with pkgs; [ android-studio ];
    };
}
