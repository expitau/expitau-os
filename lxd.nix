{ config, pkgs, lib, ... }:
{
  # Enable LXD
  virtualisation.lxd = {
    enable = true;
    recommendedSysctlSettings = true;
  };

  # Allow LXD to pass through firewall
  networking.firewall = {
    trustedInterfaces = [ "lxdbr0" ];
    extraCommands = ''
      iptables -A FORWARD -i eth0 -o lxdbr0 -j ACCEPT
      iptables -A FORWARD -i lxdbr0 -o eth0 -j ACCEPT
    '';
  };
  networking.nat = {
    enable = true;
    internalInterfaces = [ "lxdbr0" ];
    externalInterface = "wlp0s20f3";
  };

  # Enable *.lxd domains to be resolved via lxdbr0
  systemd.services."lxdbr0-resolved" = {
    description = "Attach LXD DNS to lxdbr0 for *.lxd";
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];
    serviceConfig.Type = "oneshot";
    script = ''
      /run/current-system/sw/bin/resolvectl dns lxdbr0 10.55.95.1
      /run/current-system/sw/bin/resolvectl domain lxdbr0 '~lxd'
    '';
    wantedBy = [ "multi-user.target" ];
  };
}
