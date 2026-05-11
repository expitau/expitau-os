{
  config,
  pkgs,
  lib,
  ...
}:
{
  nixpkgs.config.permittedInsecurePackages = [
    "minio-2025-10-15T17-29-55Z"
  ];

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
  networking.firewall.trustedInterfaces = [
    "incusbr0"
    "tailscale0"
  ];

  # Enable *.incus domains to be resolved via incusbr0
  systemd.services."incus-resolved" = {
    description = "Attach Incus DNS to incusbr0 for *.incus";
    after = [
      "network-online.target"
      "incus.service"
    ];
    requires = [ "incus.service" ];
    wants = [ "network-online.target" ];
    serviceConfig.Type = "oneshot";
    script = ''
      /run/current-system/sw/bin/resolvectl dns incusbr0 192.168.11.1
      /run/current-system/sw/bin/resolvectl domain incusbr0 '~incus'
    '';
    wantedBy = [ "multi-user.target" ];
  };

  environment.systemPackages = with pkgs; [
    xhost
  ];
}
