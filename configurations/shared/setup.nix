{
  config,
  pkgs,
  lib,
  ...
}:
{
  imports = [
    ./home.nix
  ];

  ### Boot and firmware
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.plymouth = {
    enable = true;
    theme = "bgrt";
  };
  boot.kernelParams = [
    "quiet"
    "udev.log_level=3"
  ];

  ### Nix settings
  nix.settings.experimental-features = [
    "flakes"
    "nix-command"
  ];
  nixpkgs.config.allowUnfree = true;

  ### Audio
  services.pulseaudio.enable = false;
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
  };

  ### Networking
  networking.networkmanager.enable = true;
  services.resolved.enable = true;

  services.fwupd.enable = true;

  ### Timezone, locale, keymap
  time.timeZone = "America/Toronto";
  i18n.defaultLocale = "en_CA.UTF-8";

  ### Additional services
  services.printing.enable = true;
  programs.mtr.enable = true; # Ping and traceroute

  ### Desktop environment
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

  ### User setup
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

  ### Shared packages
  fonts.packages = [ pkgs.fira-code ];
  environment.systemPackages = with pkgs; [
    mission-center

    git
    fastfetch
    alsa-utils
    gnumake
    tree
    nixfmt

    gnomeExtensions.blur-my-shell
    gnomeExtensions.color-picker
    gnomeExtensions.caffeine
  ];

  ### State
  home-manager.backupFileExtension = "nix-backup";
  home-manager.users.nathan.home.stateVersion = "25.05";
  system.stateVersion = "25.05";
}
