{
  config,
  pkgs,
  lib,
  ...
}:
{
  environment.etc = {
    "dbus-1/session-local.conf" = {
      text = ''
        <busconfig>
          <policy context="mandatory">
            <allow user="root"/>
          </policy>
        </busconfig>
      '';
      mode = "0644";
    }
  }
}
