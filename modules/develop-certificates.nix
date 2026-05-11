{
  config,
  pkgs,
  lib,
  ...
}:
let
  certificate = builtins.readFile ../assets/localhost-ca.crt;
in
{
  security.pki.certificates = [ certificate ];

  # environment.etc."NetworkManager/dnsmasq.d/proxy.conf".text = ''
  #   address=/mylocalhost/127.0.0.1
  #   server=/incus/192.168.11.1
  # '';
}
