{ pkgs, ... }:
{
  environment.systemPackages = with pkgs; [
    vscode
  ];

  services.tailscale.enable = true;

  programs.firefox.enable = true;
}
