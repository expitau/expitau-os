# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).

{ config, pkgs, ... }:

# Start with pkgs.alsa-ucm-conf
let
  rootPath = ../..;
  custom-alsa-ucm-conf = pkgs.alsa-ucm-conf.overrideAttrs (oldAttrs: {
    wttsrc = pkgs.fetchFromGitHub {
      owner = "WeirdTreeThing";
      repo = "alsa-ucm-conf-cros";
      rev = "1908a457c7f2bf8b63264fe3b1e0522ea632ac5a";
      hash = "sha256-h4qphJgXlEGMjpV4+llTaJeM3hoglmmgkXY8rOp+MAI=";
    };

    # Then copy WeirdTreeThing/ucm2 to the share/alsa directory in pkgs.alsa-ucm-conf
    postInstall = ''
      cp -rf $wttsrc/ucm2 $out/share/alsa/
    '';
  });
in
{
  imports = [
    (rootPath + /hardware-configuration.nix)

    ../shared/setup.nix
  ];

  home-manager.users.nathan.home.file = {
    ".bashrc".source = ../../assets/bashrc.bash;

    "Documents/sheetmusic".source =
      pkgs.runCommand "sheetmusic"
        {
          nativeBuildInputs = [ pkgs.unzip ];
        }
        ''
          mkdir -p "$out"
          unzip -q ${../../assets/SheetMusic.zip} -d "$out"
        '';

    "Documents/wallpaper.png".source = ../../assets/maze.png;
  };

  home-manager.users.nathan.dconf.settings = {

    "org/gnome/desktop/background" = {
      picture-uri = "file:///home/nathan/Documents/wallpaper.png";
      picture-uri-dark = "file:///home/nathan/Documents/wallpaper.png";
    };

    "org/gnome/desktop/screensaver" = {
      picture-uri = "file:///home/nathan/Documents/wallpaper.png";
      picture-uri-dark = "file:///home/nathan/Documents/wallpaper.png";
    };

    "org/gnome/settings-daemon/plugins/media-keys" = {
      custom-keybindings = [
        "/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom0/"
        "/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom1/"
      ];
    };
    "org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom0" = {
      binding = "<Super>AudioRaiseVolume";
      command = "sh -c \"nix run nixpkgs#gnome-randr -- modify eDP-1 --rotate inverted && firefox https://musescore.com/user/38065345/favorites\"";
      name = "Music mode";
    };

    "org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom1" = {
      binding = "<Super>AudioLowerVolume";
      command = "nix run nixpkgs#gnome-randr -- modify eDP-1 --rotate normal";
      name = "Uninvert display";
    };

    "org/gnome/shell" = {
      enabled-extensions = [
        "gsconnect@andyholmes.github.io"
      ];
    };
  };

  networking.hostName = "acetic";

  environment.systemPackages = with pkgs; [
    vscode
  ];

  services.tailscale.enable = true;

  programs.firefox.enable = true;

  programs.kdeconnect = {
    enable = true;
    package = pkgs.gnomeExtensions.gsconnect;
  };

  # Tell the environment variable to see our custom config
  environment.sessionVariables.ALSA_CONFIG_UCM2 = "${custom-alsa-ucm-conf}/share/alsa/ucm2";

  # Enable sound with pipewire.
  services.pulseaudio.enable = false;
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
    # If you want to use JACK applications, uncomment this
    #jack.enable = true;

    # use the example session manager (no others are packaged yet so this is enabled by default,
    # no need to redefine it in your config for now)
    #media-session.enable = true;
  };

  services.logind.settings.Login = {
    HandlePowerKey = "suspend";
  };

  security.sudo.wheelNeedsPassword = false;

  services.openssh.enable = true;
  services.openssh.settings.PasswordAuthentication = false;
  services.openssh.settings.PermitRootLogin = "no";
  users.users.nathan.openssh.authorizedKeys.keys = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIG22iWrUnhnXf1BIIX+9gfHaKVNu82r/0U8/ZiVPJZXS nathan@formic"
  ];
}
