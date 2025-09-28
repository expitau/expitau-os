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

  home-manager.users.nathan.home.file = {
    "Data/libvirt/edk-2-i386-vars.fd".source = "${pkgs.qemu}/share/qemu/edk2-i386-vars.fd";
  }
}
