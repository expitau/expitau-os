{
  config,
  pkgs,
  lib,
  ...
}:
let
  certificate = builtins.readFile ./localhost-ca.crt;
in
{
  security.pki.certificates = [ certificate ];
}
