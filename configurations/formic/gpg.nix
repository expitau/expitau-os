{ pkgs, config, ... }:
{
  # Install gpg
  programs.gpg.enable = true;
  services.gpg-agent = {
    enable = true;
    enableSshSupport = true;
    pinentry.package = pkgs.pinentry-gnome3;
  };

  # Exported with
  # `gpg --export-secret-keys --armor <key-id> > gpg.asc`
  # `gpg --export-ownertrust --armor > ownertrust.txt
  systemd.user.services.import-gpg-keys = {
    Unit = {
      Description = "Import GPG keys";
      ConditionPathExists = "${config.home.homeDirectory}/Data/AppData/gpg/gpg.asc";
    };
    Service = {
      Type = "oneshot";
      ExecStart = [
        "${pkgs.gnupg}/bin/gpg --batch --import ${config.home.homeDirectory}/Data/AppData/gpg/gpg.asc"
        "${pkgs.gnupg}/bin/gpg --import-ownertrust ${config.home.homeDirectory}/Data/AppData/gpg/ownertrust.txt"
      ];
    };
    Install.WantedBy = [ "default.target" ];
  };
}
