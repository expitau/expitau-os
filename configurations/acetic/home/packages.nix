{ pkgs, ... }:
{
  environment.systemPackages = with pkgs; [
    vscode
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

  services.tailscale.enable = true;

  programs.firefox.enable = true;

  fonts.packages = [ pkgs.fira-code ];
}
