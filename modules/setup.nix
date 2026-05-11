{
  config,
  pkgs,
  lib,
  ...
}:
{
  ### Boot and firmware
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.plymouth = {
    enable = true;
    theme = "bgrt";
  };
  boot.initrd.systemd.enable = true;
  boot.kernelParams = [
    "quiet"
    "udev.log_level=3"
  ];

  nix.settings.experimental-features = [
    "flakes"
    "nix-command"
  ];
  nixpkgs.config.allowUnfree = true;

  networking.networkmanager.enable = true;
  services.resolved.enable = true;

  services.fwupd.enable = true;

  # Timezone, locale, keymap
  time.timeZone = "America/Toronto";
  i18n.defaultLocale = "en_CA.UTF-8";
  services.xserver.xkb = {
    layout = "us";
    variant = "";
  };

  # Enable CUPS to print documents.
  services.printing.enable = true;

  # Some programs need SUID wrappers, can be configured further or are
  # started in user sessions.
  programs.mtr.enable = true;
  programs.gnupg.agent = {
    enable = true;
    enableSSHSupport = true;
  };
}
