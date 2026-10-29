# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).

{
  config,
  pkgs,
  lib,
  inputs,
  ...
}:
let
  rootPath = ../..;
  home-config = config.home-manager.users.nathan;
in
{
  imports = [
    (rootPath + /hardware-configuration.nix)

    (rootPath + /modules/install-incus.nix)
    (rootPath + /modules/install-rustdesk.nix)
    (rootPath + /modules/install-keysnek.nix)
    (rootPath + /modules/install-virtualization.nix)

    (../shared/setup.nix)
  ];

  home-manager.users.nathan.home.file = {
    ".bashrc".source = ../../assets/bashrc.bash;

    "Documents".source =
      home-config.lib.file.mkOutOfStoreSymlink "${home-config.home.homeDirectory}/Data/Documents";
    "Games".source = home-config.lib.file.mkOutOfStoreSymlink "${home-config.home.homeDirectory}/Data/Games";
    "Music".source = home-config.lib.file.mkOutOfStoreSymlink "${home-config.home.homeDirectory}/Data/Music";
    "Projects".source =
      home-config.lib.file.mkOutOfStoreSymlink "${home-config.home.homeDirectory}/Data/Projects";
    "Pictures".source =
      home-config.lib.file.mkOutOfStoreSymlink "${home-config.home.homeDirectory}/Data/Pictures";
    "Videos".source = home-config.lib.file.mkOutOfStoreSymlink "${home-config.home.homeDirectory}/Data/Videos";
    "Downloads".source =
      home-config.lib.file.mkOutOfStoreSymlink "${home-config.home.homeDirectory}/Data/Cache/Downloads";

    ".config/StardewValley/Saves".source =
      home-config.lib.file.mkOutOfStoreSymlink "${home-config.home.homeDirectory}/Games/Stardew Valley";
    ".local/share/Terraria".source =
      home-config.lib.file.mkOutOfStoreSymlink "${home-config.home.homeDirectory}/Games/Terraria";
    ".local/share/Celeste".source =
      home-config.lib.file.mkOutOfStoreSymlink "${home-config.home.homeDirectory}/Games/Celeste";
    ".factorio".source =
      home-config.lib.file.mkOutOfStoreSymlink "${home-config.home.homeDirectory}/Games/Factorio";
    ".config/unity3d/Klei/Oxygen Not Included".source =
      home-config.lib.file.mkOutOfStoreSymlink "${home-config.home.homeDirectory}/Games/Oxygen Not Included";
    ".config/unity3d/Team Cherry/Hollow Knight".source =
      home-config.lib.file.mkOutOfStoreSymlink "${home-config.home.homeDirectory}/Games/Hollow Knight";
    ".config/unity3d/Team Cherry/Hollow Knight Silksong".source =
      home-config.lib.file.mkOutOfStoreSymlink "${home-config.home.homeDirectory}/Games/Silksong";
    ".local/share/PrismLauncher/instances/Default/minecraft/saves".source =
      home-config.lib.file.mkOutOfStoreSymlink "${home-config.home.homeDirectory}/Games/Minecraft";
    # "Data/AppData/steam/steamapps/common/Cuphead/Saves".source =
    #   home-config.lib.file.mkOutOfStoreSymlink "${home-config.home.homeDirectory}/Games/Cuphead";

    ".config/Code".source =
      home-config.lib.file.mkOutOfStoreSymlink "${home-config.home.homeDirectory}/Data/AppData/vscode";
    ".config/discord".source =
      home-config.lib.file.mkOutOfStoreSymlink "${home-config.home.homeDirectory}/Data/AppData/discord";
    ".mozilla".source =
      home-config.lib.file.mkOutOfStoreSymlink "${home-config.home.homeDirectory}/Data/AppData/firefox";
    ".thunderbird".source =
      home-config.lib.file.mkOutOfStoreSymlink "${home-config.home.homeDirectory}/Data/AppData/thunderbird";
    ".config/obsidian".source =
      home-config.lib.file.mkOutOfStoreSymlink "${home-config.home.homeDirectory}/Data/AppData/obsidian";
    ".local/share/Steam".source =
      home-config.lib.file.mkOutOfStoreSymlink "${home-config.home.homeDirectory}/Data/AppData/steam";
    ".config/pika-backup".source =
      home-config.lib.file.mkOutOfStoreSymlink "${home-config.home.homeDirectory}/Data/AppData/pika";
    ".config/pipewire/pipewire.conf".source =
      home-config.lib.file.mkOutOfStoreSymlink "${home-config.home.homeDirectory}/Data/AppData/configs/pipewire.conf";
    ".ssh".source = home-config.lib.file.mkOutOfStoreSymlink "${home-config.home.homeDirectory}/Data/AppData/ssh";
    ".nixos".source =
      home-config.lib.file.mkOutOfStoreSymlink "${home-config.home.homeDirectory}/Data/AppData/nixos";
    ".devbox".source =
      home-config.lib.file.mkOutOfStoreSymlink "${home-config.home.homeDirectory}/Data/AppData/devbox";
  };

  home-manager.users.nathan.dconf.settings = {
    "org/gnome/login-screen" = {
      enable-fingerprint-authentication = true;
      enable-smartcard-authentication = false;
    };

    "org/gnome/settings-daemon/plugins/media-keys" = {
      custom-keybindings = [
        "/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom0/"
      ];
    };

    "org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom0" = {
      binding = "<Control><Shift><Super>b";
      command = "sh -c \"wpctl set-default \\$(wpctl status | grep -e \\\"Alder Lake .* DisplayPort 1\\\" | sed -nE 's/[^0-9]*([0-9]+).*$/\\1/p') && firefox -P Default https://www.netflix.com/browse\"";
      name = "Launch movie";
    };

    "org/gnome/shell" = {
      enabled-extensions = [
        "blur-my-shell@aunetx"
        "color-picker@tuberry"
        "caffeine@patapon.info"
        "gsconnect@andyholmes.github.io"
      ];
      favorite-apps = [
        "firefox.desktop"
        "org.gnome.Nautilus.desktop"
        "org.gnome.TextEditor.desktop"
        "code.desktop"
        "org.gnome.Console.desktop"
        "discord.desktop"
        "slack.desktop"
      ];
    };
  };

  networking.hostName = "formic";

  environment.systemPackages = with pkgs; [
    vscode
    discord
    pika-backup
    thunderbird
    krita
    slack
    prismlauncher # Minecraft launcher
    mission-center

    git
    fastfetch
    alsa-utils
    gnumake
    tree
    nixfmt
    # platformio

    gnomeExtensions.blur-my-shell
    gnomeExtensions.color-picker
    gnomeExtensions.caffeine
  ];

  programs.steam.enable = true;
  services.tailscale.enable = true;
  programs.firefox.enable = true;

  programs.kdeconnect = {
    enable = true;
    package = pkgs.gnomeExtensions.gsconnect;
  };

  ### XPS specific audio fix
  systemd.services.mic-alsa-setup = {
    description = "Set ALSA capture path for internal mic (rt714)";
    wantedBy = [ "multi-user.target" ];
    after = [
      "sound.target"
      "wireplumber.service"
    ]; # wireplumber if you use PipeWire
    serviceConfig.Type = "oneshot";
    script = ''
      # Target the sof-soundwire card; adjust -c if your card index/name differs.
      ${pkgs.alsa-utils}/bin/amixer -c 0 cset name='PGA5.0 5 Master Capture Switch' on,on
      ${pkgs.alsa-utils}/bin/amixer -c 0 cset name='PGA5.0 5 Master Capture Volume' 70,70
      ${pkgs.alsa-utils}/bin/amixer -c 0 cset name='rt714 ADC 22 Mux' 4
    '';
  };

  ### 4 - Nvidia
  services.xserver.videoDrivers = [ "nvidia" ];

  hardware.graphics = {
    enable = true;
  };
  hardware.nvidia = {
    # Modesetting is required.
    modesetting.enable = true;

    # Nvidia power management. Experimental, and can cause sleep/suspend to fail.
    # Enable this if you have graphical corruption issues or application crashes after waking
    # up from sleep. This fixes it by saving the entire VRAM memory to /tmp/ instead
    # of just the bare essentials.
    powerManagement.enable = false;

    # Fine-grained power management. Turns off GPU when not in use.
    # Experimental and only works on modern Nvidia GPUs (Turing or newer).
    powerManagement.finegrained = false;

    # Use the NVidia open source kernel module (not to be confused with the
    # independent third-party "nouveau" open source driver).
    # Support is limited to the Turing and later architectures. Full list of
    # supported GPUs is at:
    # https://github.com/NVIDIA/open-gpu-kernel-modules#compatible-gpus
    # Only available from driver 515.43.04+
    open = true;

    # Enable the Nvidia settings menu,
    # accessible via `nvidia-settings`.
    nvidiaSettings = true;

    # Optionally, you may need to select the appropriate driver version for your specific GPU.
    package = config.boot.kernelPackages.nvidiaPackages.stable;

    prime = {
      sync.enable = true;
      intelBusId = "PCI:0:2:0";
      nvidiaBusId = "PCI:1:0:0";
    };
  };
  boot.extraModprobeConfig = ''
    options nvidia_modeset vblank_sem_control=0 nvidia NVreg_PreserveVideoMemoryAllocations=1  NVreg_TemporaryFilePath=/var/tmp
  '';

  # Input and fingerprint
  services.fprintd.enable = true;
  services.libinput.enable = true;
}
