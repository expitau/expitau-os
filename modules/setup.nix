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

  # Enable CUPS to print documents.
  services.printing.enable = true;

  # Some programs need SUID wrappers, can be configured further or are
  # started in user sessions.
  programs.mtr.enable = true;
  programs.gnupg.agent = {
    enable = true;
    enableSSHSupport = true;
  };

  services.xserver = {
    enable = true;
    excludePackages = [ pkgs.xterm ];
    xkb = {
      layout = "us";
      variant = "";
    };
  };

  services.displayManager.gdm.enable = true;
  services.desktopManager.gnome.enable = true;
  environment.gnome.excludePackages = [
    pkgs.gnome-contacts
    pkgs.gnome-tour
    pkgs.simple-scan
    pkgs.gnome-system-monitor
    pkgs.gnome-characters
    pkgs.gnome-font-viewer
    pkgs.gnome-maps
    pkgs.gnome-music
    pkgs.gnome-connections
    pkgs.decibels
    pkgs.epiphany
    pkgs.file-roller
    pkgs.geary
    pkgs.seahorse
    pkgs.yelp
  ];
}
