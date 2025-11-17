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
    "Data/AppData/libvirt/edk2-i386-vars.fd".source = "${pkgs.qemu}/share/qemu/edk2-i386-vars.fd";
    "Data/AppData/libvirt/edk2-x86_64-secure-code.fd".source =
      "${pkgs.qemu}/share/qemu/edk2-x86_64-secure-code.fd";

    ".local/share/applications/windows-sandbox.desktop".text = ''
      [Desktop Entry]
      Name=Windows Sandbox
      Comment=Revert snapshot and launch virt-viewer for Windows
      Exec=bash -c "/home/nathan/Data/AppData/libvirt/create-sandbox.sh windows-sandbox"
      Terminal=false
      Type=Application
      Icon=computer
    '';

    ".local/share/applications/ubuntu-sandbox.desktop".text = ''
      [Desktop Entry]
      Name=Ubuntu Sandbox
      Comment=Revert snapshot and launch virt-viewer for Ubuntu
      Exec=bash -c "/home/nathan/Data/AppData/libvirt/create-sandbox.sh ubuntu-sandbox"
      Terminal=false
      Type=Application
      Icon=computer
    '';
  };
}
