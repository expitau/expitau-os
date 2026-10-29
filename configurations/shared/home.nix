{
  home-manager.users.nathan.imports = [
    (
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
    )
    (
      {
        config,
        pkgs,
        lib,
        ...
      }:
      {
        dconf.settings = {
          "org/gnome/desktop/background" = {
            picture-uri = "file:///home/nathan/Data/AppData/wallpaper.png";
            picture-uri-dark = "file:///home/nathan/Data/AppData/wallpaper.png";
          };

          "org/gnome/desktop/screensaver" = {
            picture-uri = "file:///home/nathan/Data/AppData/wallpaper.png";
            picture-uri-dark = "file:///home/nathan/Data/AppData/wallpaper.png";
          };

          "org/gnome/desktop/interface" = {
            color-scheme = "prefer-dark";
            clock-format = "12h";
            clock-show-seconds = false;
            clock-show-weekday = false;
          };

          "org/gnome/desktop/datetime" = {
            automatic-timezone = false;
          };

          "org/gnome/desktop/peripherals/touchpad" = {
            disable-while-typing = true;
            two-finger-scrolling-enabled = true;
          };

          "org/gnome/desktop/sound" = {
            allow-volume-above-100-percent = true;
          };

          "org/gnome/mutter" = {
            workspaces-only-on-primary = false;
          };

          "org/gnome/settings-daemon/plugins/color" = {
            night-light-enabled = true;
            night-light-schedule-automatic = false;
            night-light-schedule-from = 21.0;
            night-light-temperature = 2700;
          };

          "org/gnome/settings-daemon/plugins/power" = {
            ambient-enabled = false;
          };

          "org/gnome/system/location" = {
            enabled = false;
          };

          "org/gnome/shell/keybindings" = {
            show-screenshot-ui = [ "<Shift><Super>s" ];
          };
          "org/gnome/shell/extensions/color-picker" = {
            color-picker-shortcut = [ "<Shift><Super>c" ];
            enable-preview = true;
            enable-shortcut = true;
            enable-sound = false;
            enable-systray = false;
            format-menu = false;
          };

          "org/gnome/shell/extensions/blur-my-shell/dash-to-dock" = {
            static-blur = true;
            style-dash-to-dock = 0;
          };
          "org/gnome/shell/extensions/blur-my-shell/popup" = {
            pipeline = "pipeline_classic_dark_background";
            static-blur = false;
            style-popup = 0;
          };


          "org/gnome/shell" = {
            enabled-extensions = [
              "blur-my-shell@aunetx"
              "color-picker@tuberry"
              "caffeine@patapon.info"
            ];
          };

          "org/gnome/Weather" = {
            locations = [
              # Waterloo coordinates
              "(uint32 2, ('Waterloo', 'CYKF', true, [(0.75863645401796609, -1.402953824577011)], [(0.75863645401796609, -1.4055718184550026)]))"
            ];
          };
          "org/gnome/calculator" = {
            accuracy = 9;
            angle-units = "degrees";
            base = 10;
            button-mode = "advanced";
            number-format = "automatic";
            refresh-interval = 604800;
            show-thousands = false;
            show-zeroes = false;
            source-currency = "";
            source-units = "degree";
            target-currency = "";
            target-units = "radian";
            word-size = 64;
          };
          "org/gnome/calendar" = {
            active-view = "month";
          };

          "org/gnome/nautilus/compression" = {
            default-compression-format = "zip";
          };

          "org/gnome/nautilus/preferences" = {
            default-folder-viewer = "list-view";
            migrated-gtk-settings = true;
            search-filter-time-type = "last_modified";
          };

          "org/gtk/gtk4/settings/file-chooser" = {
            date-format = "regular";
            location-mode = "path-bar";
            show-hidden = false;
            sort-column = "name";
            sort-directories-first = false;
            sort-order = "ascending";
            type-format = "category";
            view-type = "list";
          };

          "org/gtk/settings/file-chooser" = {
            date-format = "regular";
            location-mode = "path-bar";
            show-hidden = false;
            sort-column = "name";
            sort-directories-first = false;
            sort-order = "ascending";
            type-format = "category";
            view-type = "list";
          };

          "org/virt-manager/virt-manager/connections" = {
            autoconnect = [ "qemu:///system" ];
            uris = [ "qemu:///system" ];
          };
        };
      }
    )
  ];
}
