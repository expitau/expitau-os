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

  networking.libvirt = {
    networks."default" = {
      # NAT mode (like virbr0 normally does)
      forward.mode = "nat";
      bridge = "virbr0";
      addresses = [ {
        address = "192.168.122.1";
        prefixLength = 24;
      } ];
      dhcp.range = {
        start = "192.168.122.2";
        end = "192.168.122.254";
      };
    };
  };
}
