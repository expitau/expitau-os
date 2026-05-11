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
in
{
  imports = [
    (rootPath + /hardware-configuration.nix)

    (rootPath + /modules/setup.nix)
    (rootPath + /modules/develop-certificates.nix)

    (rootPath + /modules/install-incus.nix)
    (rootPath + /modules/install-keysnek.nix)
    (rootPath + /modules/install-virtualization.nix)

    ./home/user.nix
    ./home/packages.nix
    ./home/home.nix
    ./home/dconf.nix
  ];

  # Enable sound with pipewire.
  services.pulseaudio.enable = false;
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
  };
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

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It‘s perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "25.05"; # Did you read the comment?
}
