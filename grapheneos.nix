{
  config,
  pkgs,
  lib,
  ...
}:
{
  programs.adb.enable = true;
  users.users.nathan.extraGroups = [
    "adbusers"
    "kvm"
  ];
}
