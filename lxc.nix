{
  config,
  pkgs,
  lib,
  ...
}:
{
  # Enable LXD
  virtualisation.incus.enable = true;

  virtualisation.incus.preseed = {
    networks = [
      {
        config = {
          "ipv4.address" = "192.168.11.1/24";
          "ipv4.nat" = "true";
        };
        name = "incusbr0";
        type = "bridge";
      }
    ];
    profiles = [
      {
        devices = {
          eth0 = {
            name = "eth0";
            network = "incusbr0";
            type = "nic";
          };
          root = {
            path = "/";
            pool = "default";
            size = "35GiB";
            type = "disk";
          };
        };
        name = "default";
      }
    ];
    storage_pools = [
      {
        config = {
          source = "/var/lib/incus/storage-pools/default";
        };
        driver = "dir";
        name = "default";
      }
    ];
  };

  networking.nftables.enable = true;
  networking.firewall.trustedInterfaces = [ "incusbr0" ];

  # # Allow LXD to pass through firewall
  # networking.firewall = {
  #   trustedInterfaces = [ "lxdbr0" ];
  #   extraCommands = ''
  #     iptables -A FORWARD -i wlp0s20f3 -o lxdbr0 -j ACCEPT
  #     iptables -A FORWARD -i lxdbr0 -o wlp0s20f3 -j ACCEPT
  #   '';
  # };
  # networking.nat = {
  #   enable = true;
  #   internalInterfaces = [ "lxdbr0" ];
  #   externalInterface = "wlp0s20f3";
  # };

  # Enable *.lxc domains to be resolved via incusbr0
  systemd.services."incus-resolved" = {
    description = "Attach Incus DNS to incusbr0 for *.lxc";
    after = [ "network-online.target" "incus.service" ];
    requires = [ "incus.service" ];
    wants = [ "network-online.target" ];
    serviceConfig.Type = "oneshot";
    script = ''
      /run/current-system/sw/bin/resolvectl dns incusbr0 192.168.11.1
      /run/current-system/sw/bin/resolvectl domain incusbr0 '~lxc'
    '';
    wantedBy = [ "multi-user.target" ];
  };

  environment.systemPackages = with pkgs; [
    xorg.xhost
  ];
}
