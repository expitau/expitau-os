{
  config,
  pkgs,
  lib,
  ...
}:
{
  environment.systemPackages = with pkgs; [
    android-studio
    android-tools
  ];

  users.users.nathan.extraGroups = [
    "adbusers"
    "kvm"
  ];
}
