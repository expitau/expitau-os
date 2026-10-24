{
  config,
  pkgs,
  lib,
  ...
}:
{
  home.file = {
    ".bashrc".source = ../../assets/bashrc.bash;

    "Documents".source =
      config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/Data/Documents";
    "Games".source = config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/Data/Games";
    "Music".source = config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/Data/Music";
    "Projects".source =
      config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/Data/Projects";
    "Pictures".source =
      config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/Data/Pictures";
    "Videos".source = config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/Data/Videos";
    "Downloads".source =
      config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/Data/Cache/Downloads";

    ".config/StardewValley/Saves".source =
      config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/Games/Stardew Valley";
    ".local/share/Terraria".source =
      config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/Games/Terraria";
    ".local/share/Celeste".source =
      config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/Games/Celeste";
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
    ".nixos".source =
      config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/Data/AppData/nixos";
    ".devbox".source =
      config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/Data/AppData/devbox";
  };
}
