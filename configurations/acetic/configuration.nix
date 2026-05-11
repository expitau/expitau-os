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

  # Idk if we actually need this
  meta = oldAttrs.meta // {
    platforms = [
      "aarch64-linux"
      "x86_64-linux"
    ];
  };
}); in
{
  imports = [
    ./hardware-configuration.nix

    (rootPath + /modules/setup.nix)

    ./home/user.nix
    ./home/packages.nix
    ./home/home.nix
    ./home/dconf.nix
  ];

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

  security.sudo.wheelNeedsPassword = false;

  services.openssh.enable = true;
  services.openssh.passwordAuthentication = false;
  services.openssh.permitRootLogin = "no";
  users.users.nathan.openssh.authorizedKeys.keys = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIG22iWrUnhnXf1BIIX+9gfHaKVNu82r/0U8/ZiVPJZXS nathan@formic"
  ];

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It‘s perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "25.11"; # Did you read the comment?

}
