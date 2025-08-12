# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).

{ config, pkgs, lib, ... }:

let
  home-manager = builtins.fetchTarball https://github.com/nix-community/home-manager/archive/release-25.05.tar.gz;
in
{
  imports =
    [
      # Include the results of the hardware scan.
      ./hardware-configuration.nix
      (import "${home-manager}/nixos")
    ];
  nix.settings.experimental-features = [ "flakes" "nix-command" ];

  # Bootloader.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.plymouth.enable = true;

  virtualisation.lxd = {
    enable = true;
    recommendedSysctlSettings = true;
  };
  virtualisation.lxc.lxcfs.enable = true;
  networking.bridges = { lxdbr0.interfaces = []; };
  networking.localCommands = ''
    ip address add 192.168.57.1/24 dev lxdbr0
  '';
  networking.firewall.extraCommands = ''
    iptables -A INPUT -i lxdbr0 -m comment --comment "LXD network lxdbr0" -j ACCEPT

    # These three technically aren't needed, since by default the FORWARD and
    # OUTPUT firewalls accept everything everything, but lets keep them in just
    # in case.
    iptables -A FORWARD -o lxdbr0 -m comment --comment "LXD network lxdbr0" -j ACCEPT
    iptables -A FORWARD -i lxdbr0 -m comment --comment "LXD network lxdbr0" -j ACCEPT
    iptables -A OUTPUT -o lxdbr0 -m comment --comment "LXD network lxdbr0" -j ACCEPT

    iptables -t nat -A POSTROUTING -s 192.168.57.0/24 ! -d 192.168.57.0/24 -m comment --comment "LXD network lxdbr0" -j MASQUERADE
  '';
  boot.kernel.sysctl = {
    "net.ipv4.conf.all.forwarding" = true;
    "net.ipv4.conf.default.forwarding" = true;
  };
  boot.kernelModules = [ "nf_nat_ftp" ];

  networking.hostName = "nixos-xps"; # Define your hostname.
  # networking.wireless.enable = true;  # Enables wireless support via wpa_supplicant.

  # Enable networking
  networking.networkmanager.enable = true;

  # Set your time zone.
  time.timeZone = "America/Toronto";

  # Select internationalisation properties.
  i18n.defaultLocale = "en_CA.UTF-8";

  # Enable the X11 windowing system.
  services.xserver = {
    enable = true;
    excludePackages = [ pkgs.xterm ];
  };

  # Enable the GNOME Desktop Environment.
  services.xserver.displayManager.gdm.enable = true;
  services.xserver.desktopManager.gnome.enable = true;
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

  # Configure keymap in X11
  services.xserver.xkb = {
    layout = "us";
    variant = "";
  };

  # Enable CUPS to print documents.
  services.printing.enable = true;

  # Enable sound with pipewire.
  services.pulseaudio.enable = false;
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
  };

  services.libinput.enable = true;

  users.users.nathan = {
    isNormalUser = true;
    description = "nathan";
    extraGroups = [ "networkmanager" "wheel" ];
    packages = with pkgs; [
      #  thunderbird
    ];
  };

  home-manager.backupFileExtension = "nix-backup";
  home-manager.users.nathan = { pkgs, config, ... }: {
    home.stateVersion = "25.05";

    home.file = {
      ".bashrc".text = ''
        #
        # ~/.bashrc
        #

        # If not running interactively, don't do anything
        [[ $- != *i* ]] && return

        bind '"\t":menu-complete'

        alias ls='ls --color=auto'
        alias grep='grep --color=auto'

        # source /etc/profile.d/trueline.sh
        prompt_command() {
            local STATUS=$?;
            local BRANCH=$(git branch --show-current 2>/dev/null);
            
            PS1="\n╭─ \w";
            [ -n "$BRANCH" ] && PS1+=" \[\e[38;5;248m\]$BRANCH\[\e[0m\]";
            [ "$STATUS" -ne 0 ] && PS1+=" \[\e[38;5;203m\]$STATUS\[\e[0m\]";
            
            PS1+="\n╰ ";
            
            if [[ "$(uname -n)" == *devbox* ]]; then
                PS1+="\[\e[38;5;75;1m\]λ\[\e[0m\] ";
            elif [ -n "$SSH_CLIENT" ] || [ -n "$SSH_TTY" ]; then
                PS1+="\[\e[38;5;71;1m\]λ\[\e[0m\] ";
            elif [ "$(whoami)" = "root" ]; then
                PS1+="\[\e[38;5;203;1m\]λ\[\e[0m\] ";
            else
                PS1+="\[\e[38;5;141;1m\]λ\[\e[0m\] ";
            fi
        }

        PROMPT_COMMAND='prompt_command'
      '';

      "Documents".source = config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/Data/Documents";
      "Games".source = config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/Data/Games";
      "Music".source = config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/Data/Music";
      "Scripts".source = config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/Data/Scripts";
      "Pictures".source = config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/Data/Pictures";
      "Videos".source = config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/Data/Videos";

      ".config/StardewValley/Saves".source = config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/Games/Stardew Valley";
      ".local/share/Terraria".source = config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/Games/Terraria";
      ".factorio".source = config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/Games/Factorio";
      ".config/unity3d/Klei/OxygenNotIncluded".source = config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/Games/Oxygen Not Included";
      ".config/unity3d/Team Cherry/Hollow Knight".source = config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/Games/Hollow Knight";
      ".local/share/Steam/steamapps/common/Cuphead/Saves".source = config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/Games/Cuphead";

      ".config/Code".source = config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/Data/AppData/vscode";
      ".config/discord".source = config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/Data/AppData/discord";
      ".mozilla".source = config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/Data/AppData/firefox";
      ".config/obsidian".source = config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/Data/AppData/obsidian";
      ".local/share/.steam".source = config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/Data/AppData/steam";
      ".ssh".source = config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/Data/AppData/ssh";
      ".gnupg".source = config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/Data/AppData/gnupg";
    };

    dconf.settings = {
      "org/gnome/desktop/background" = {
        picture-uri = "file:///etc/nixos/wallpaper.png";
        picture-uri-dark = "file:///etc/nixos/wallpaper.png";
      };

      "org/gnome/desktop/screensaver" = {
        picture-uri = "file:///etc/nixos/wallpaper.png";
        picture-uri-dark = "file:///etc/nixos/wallpaper.png";
      };

      "org/gnome/desktop/interface" = {
        color-scheme = "prefer-dark";
        clock-format = "12h";
        clock-show-seconds = false;
        clock-show-weekday = false;
      };

      "org/gnome/desktop/datetime" = {
        automatic-timezone = false;
      };

      "org/gnome/desktop/peripherals/touchpad" = {
        disable-while-typing = true;
        two-finger-scrolling-enabled = true;
      };

      "org/gnome/desktop/sound" = {
        allow-volume-above-100-percent = true;
      };

      "org/gnome/login-screen" = {
        enable-fingerprint-authentication = true;
        enable-smartcard-authentication = false;
      };

      "org/gnome/mutter" = {
        workspaces-only-on-primary = false;
      };

      "org/gnome/settings-daemon/plugins/color" = {
        night-light-enabled = true;
        night-light-schedule-automatic = false;
        night-light-schedule-from = 21.0;
        night-light-temperature = 2700;
      };

      "org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom0" = {
        binding = "<Control><Alt><Super>b";
        command = "firefox https://meet.google.com/npf-febz-wzr";
        name = "Launch bean call";
      };

      "org/gnome/settings-daemon/plugins/power" = {
        ambient-enabled = false;
      };

      "org/gnome/system/location" = {
        enabled = false;
      };

      "org/gnome/shell/keybindings" = {
        show-screenshot-ui = [ "<Shift><Super>s" ];
      };

      "org/gnome/shell/extensions/color-picker" = {
        color-picker-shortcut = [ "<Shift><Super>c" ];
        enable-preview = true;
        enable-shortcut = true;
        enable-sound = false;
        enable-systray = false;
        format-menu = false;
      };

      "org/gnome/shell" = {
        enabled-extensions = [
          "blur-my-shell@aunetx"
          "color-picker@tuberry"
          "caffeine@patapon.info"
        ];
        favorite-apps = [
          "firefox.desktop"
          "org.gnome.Nautilus.desktop"
          "org.gnome.TextEditor.desktop"
          "code.desktop"
          "org.gnome.Console.desktop"
          "discord.desktop"
        ];
      };

      "org/gnome/Weather" = {
        locations = [
          # Waterloo coordinates
          "(uint32 2, ('Waterloo', 'CYKF', true, [(0.75863645401796609, -1.402953824577011)], [(0.75863645401796609, -1.4055718184550026)]))"
        ];
      };

      "org/gnome/calculator" = {
        accuracy = 9;
        angle-units = "degrees";
        base = 10;
        button-mode = "advanced";
        number-format = "automatic";
        refresh-interval = 604800;
        show-thousands = false;
        show-zeroes = false;
        source-currency = "";
        source-units = "degree";
        target-currency = "";
        target-units = "radian";
        word-size = 64;
      };

      "org/gnome/calendar" = {
        active-view = "month";
      };

      "org/gnome/nautilus/compression" = {
        default-compression-format = "zip";
      };

      "org/gnome/nautilus/preferences" = {
        default-folder-viewer = "list-view";
        migrated-gtk-settings = true;
        search-filter-time-type = "last_modified";
      };

      "org/gtk/gtk4/settings/file-chooser" = {
        date-format = "regular";
        location-mode = "path-bar";
        show-hidden = false;
        sort-column = "name";
        sort-directories-first = false;
        sort-order = "ascending";
        type-format = "category";
        view-type = "list";
      };

      "org/gtk/settings/file-chooser" = {
        date-format = "regular";
        location-mode = "path-bar";
        show-hidden = false;
        sort-column = "name";
        sort-directories-first = false;
        sort-order = "ascending";
        type-format = "category";
        view-type = "list";
      };
    };
  };

  # Install firefox.
  programs.firefox.enable = true;

  # Allow unfree packages
  nixpkgs.config.allowUnfree = true;

  # List packages installed in system profile. To search, run:
  # $ nix search wget
  environment.systemPackages = with pkgs; [
    #  vim # Do not forget to add an editor to edit configuration.nix! The Nano editor is also installed by default.
    vscode
    fastfetch
    discord
    pika-backup
    mission-center
    krita
    slack

    gnomeExtensions.blur-my-shell
    gnomeExtensions.color-picker
    gnomeExtensions.caffeine
  ];

  fonts.packages = [ pkgs.fira-code ];

  

  # Some programs need SUID wrappers, can be configured further or are
  # started in user sessions.
  programs.mtr.enable = true;
  programs.gnupg.agent = {
    enable = true;
    enableSSHSupport = true;
  };
  programs.steam.enable = true;

  # Open ports in the firewall.
  # networking.firewall.allowedTCPPorts = [ ... ];
  # networking.firewall.allowedUDPPorts = [ ... ];

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It‘s perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "25.05"; # Did you read the comment?

}
