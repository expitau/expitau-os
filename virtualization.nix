{
  config,
  pkgs,
  lib,
  ...
}:
{
  programs.virt-manager.enable = true;

  users.groups.libvirtd.members = [ "nathan" ];

  virtualisation.libvirtd.enable = true;
  virtualisation.libvirtd.qemu.swtpm.enable = true;

  virtualisation.spiceUSBRedirection.enable = true;

  # Add virt viewer package
  environment.systemPackages = with pkgs; [
    virt-viewer
  ];

  networking.firewall.trustedInterfaces = [ "virbr0" ];
}
