{
  networking.hostName = "acetic";
  users.users.nathan = {
    isNormalUser = true;
    description = "Nathan";
    extraGroups = [
      "networkmanager"
      "wheel"
      "incus-admin"
      "dialout"
    ];
  };
}
