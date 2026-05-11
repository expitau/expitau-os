{ pkgs, config, ... }:

{
  home-manager.backupFileExtension = "nix-backup";

  home-manager.users.nathan = {
    imports = [
      (
        {
          config,
          pkgs,
          lib,
          ...
        }:
        {
          home.file = {
            ".bashrc".text = ''
              #
              # ~/.bashrc
              #

              # If not running interactively, don't do anything
              [[ $- != *i* ]] && return

              bind '"\t":menu-complete'

              alias ls='ls --color=auto'
              alias grep='grep --color=auto'

              # source /etc/profile.d/trueline.sh
              prompt_command() {
                  local STATUS=$?;
                  local BRANCH=$(git branch --show-current 2>/dev/null);
                  
                  PS1="\n╭─ \w";
                  [ -n "$BRANCH" ] && PS1+=" \[\e[38;5;248m\]$BRANCH\[\e[0m\]";
                  [ "$STATUS" -ne 0 ] && PS1+=" \[\e[38;5;203m\]$STATUS\[\e[0m\]";
                  
                  PS1+="\n╰ ";
                  
                  if [[ "$(uname -n)" == *devbox* ]]; then
                      PS1+="\[\e[38;5;75;1m\]λ\[\e[0m\] ";
                  elif [ -n "$SSH_CLIENT" ] || [ -n "$SSH_TTY" ]; then
                      PS1+="\[\e[38;5;71;1m\]λ\[\e[0m\] ";
                  elif [ "$(whoami)" = "root" ]; then
                      PS1+="\[\e[38;5;203;1m\]λ\[\e[0m\] ";
                  else
                      PS1+="\[\e[38;5;141;1m\]λ\[\e[0m\] ";
                  fi
              }

              PROMPT_COMMAND='prompt_command'
            '';

            "Documents".source =
              config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/Data/Documents";
            "Games".source = config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/Data/Games";
            "Music".source = config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/Data/Music";
            "Scripts".source = config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/Data/Scripts";
            "Pictures".source =
              config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/Data/Pictures";
            "Videos".source = config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/Data/Videos";
            "Downloads".source =
              config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/Data/Cache/Downloads";

            ".config/StardewValley/Saves".source =
              config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/Games/Stardew Valley";
            ".local/share/Terraria".source =
              config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/Games/Terraria";
            ".factorio".source =
              config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/Games/Factorio";
            ".config/unity3d/Klei/Oxygen Not Included".source =
              config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/Games/Oxygen Not Included";
            ".config/unity3d/Team Cherry/Hollow Knight".source =
              config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/Games/Hollow Knight";
            ".config/unity3d/Team Cherry/Hollow Knight Silksong".source =
              config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/Games/Silksong";
            ".local/share/PrismLauncher/instances/Default/minecraft/saves".source =
              config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/Games/Minecraft";
            # "Data/AppData/steam/steamapps/common/Cuphead/Saves".source =
            #   config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/Games/Cuphead";

            ".config/Code".source =
              config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/Data/AppData/vscode";
            ".config/discord".source =
              config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/Data/AppData/discord";
            ".mozilla".source =
              config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/Data/AppData/firefox";
            ".thunderbird".source =
              config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/Data/AppData/thunderbird";
            ".config/obsidian".source =
              config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/Data/AppData/obsidian";
            ".local/share/Steam".source =
              config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/Data/AppData/steam";
            ".config/pika-backup".source =
              config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/Data/AppData/pika";
            ".config/pipewire/pipewire.conf".source =
              config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/Data/AppData/configs/pipewire.conf";
            ".ssh".source = config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/Data/AppData/ssh";
            ".gnupg".source =
              config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/Data/AppData/gnupg";
            ".nixos".source =
              config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/Data/AppData/nixos";
            ".devbox".source =
              config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/Data/AppData/devbox";

            "Data/AppData/libvirt/edk2-i386-vars.fd".source = "${pkgs.qemu}/share/qemu/edk2-i386-vars.fd";
            "Data/AppData/libvirt/edk2-x86_64-secure-code.fd".source =
              "${pkgs.qemu}/share/qemu/edk2-x86_64-secure-code.fd";

            ".local/share/applications/windows-sandbox.desktop".text = ''
              [Desktop Entry]
              Name=Windows Sandbox
              Comment=Revert snapshot and launch virt-viewer for Windows
              Exec=bash -c "/home/nathan/Data/AppData/libvirt/create-sandbox.sh windows-sandbox"
              Terminal=false
              Type=Application
              Icon=computer
            '';

            ".local/share/applications/ubuntu-sandbox.desktop".text = ''
              [Desktop Entry]
              Name=Ubuntu Sandbox
              Comment=Revert snapshot and launch virt-viewer for Ubuntu
              Exec=bash -c "/home/nathan/Data/AppData/libvirt/create-sandbox.sh ubuntu-sandbox"
              Terminal=false
              Type=Application
              Icon=computer
            '';
          };
        }
      )
    ];
  };

  home-manager.users.nathan.home.stateVersion = "25.05";
}
