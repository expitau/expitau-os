{
  config,
  pkgs,
  lib,
  ...
}:
let
  localhostCaPath = "/home/nathan/Data/AppData/configs/localhost-ca.crt";
in
{
  security.pki.certificates =
    if builtins.pathExists localhostCaPath then [ (builtins.readFile localhostCaPath) ] else [ ];
}
