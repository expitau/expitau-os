{ pkgs, ... }:
{
  environment.systemPackages = with pkgs; [
    vscode
    discord
    pika-backup
    thunderbird
    krita
    slack
    chromium
    prismlauncher # Minecraft launcher
    mission-center

    git
    fastfetch
    alsa-utils
    gnumake
    tree
    nixfmt
    platformio

    gnomeExtensions.blur-my-shell
    gnomeExtensions.color-picker
    gnomeExtensions.caffeine
  ];

  programs.steam.enable = true;
  services.tailscale.enable = true;

  programs.firefox.enable = true;

  fonts.packages = [ pkgs.fira-code ];

  programs.kdeconnect = {
    enable = true;
    package = pkgs.gnomeExtensions.gsconnect;
  };
}
