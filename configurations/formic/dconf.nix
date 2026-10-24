{
  config,
  pkgs,
  lib,
  ...
}:
{
  dconf.settings = {
    "org/gnome/login-screen" = {
      enable-fingerprint-authentication = true;
      enable-smartcard-authentication = false;
    };

    "org/gnome/settings-daemon/plugins/media-keys" = {
      custom-keybindings = [
        "/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom0/"
      ];
    };

    "org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom0" = {
      binding = "<Control><Shift><Super>b";
      command = "sh -c \"wpctl set-default \\$(wpctl status | grep -e \\\"Alder Lake .* DisplayPort 1\\\" | sed -nE 's/[^0-9]*([0-9]+).*$/\\1/p') && firefox -P Default https://www.netflix.com/browse\"";
      name = "Launch movie";
    };

    "org/gnome/shell" = {
      enabled-extensions = [
        "blur-my-shell@aunetx"
        "color-picker@tuberry"
        "caffeine@patapon.info"
        "gsconnect@andyholmes.github.io"
      ];
      favorite-apps = [
        "firefox.desktop"
        "org.gnome.Nautilus.desktop"
        "org.gnome.TextEditor.desktop"
        "code.desktop"
        "org.gnome.Console.desktop"
        "discord.desktop"
        "slack.desktop"
      ];
    };
  };
}
