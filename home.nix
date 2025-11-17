{ pkgs, config, ... }:

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

    ".config/StardewValley/Saves".source =
      config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/Games/Stardew Valley";
    ".local/share/Terraria".source =
      config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/Games/Terraria";
    ".factorio".source =
      config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/Games/Factorio";
    ".config/unity3d/Klei/OxygenNotIncluded".source =
      config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/Games/Oxygen Not Included";
    ".config/unity3d/Team Cherry/Hollow Knight".source =
      config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/Games/Hollow Knight";
    # ".local/share/Steam/steamapps/common/Cuphead/Saves".source =
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
    ".config/pipewire/pipewire.conf".source =
      config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/Data/AppData/configs/pipewire.conf";
    ".ssh".source = config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/Data/AppData/ssh";
    ".gnupg".source =
      config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/Data/AppData/gnupg";
    ".nixos".source =
      config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/Data/AppData/nixos";
    ".devbox".source =
      config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/Data/AppData/devbox";
  };

  dconf.settings = import ./dconf.nix;

  home.stateVersion = "25.05";
}
