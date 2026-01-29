{ inputs, self, ... }: {
  nixosModules.keysnek = {
      config,
      pkgs,
      lib,
      ...
    }:
    let
      keysnekSessionDBus = pkgs.writeTextFile {
        name = "dbus-session-extra-keysnek";
        # any of these work for session bus:
        #   /share/dbus-1/session.d/*.conf  (policy/limits)
        #   /share/dbus-1/services/*.service (bus-activation entries)
        destination = "/share/dbus-1/session.d/90-keysnek.conf";
        text = ''
          <busconfig>
            <policy context="mandatory">
              <allow user="root"/>
            </policy>
          </busconfig>
        '';
      };
    in
    {
      services.dbus.enable = true;
      services.dbus.packages = [ keysnekSessionDBus ];
    };
}
