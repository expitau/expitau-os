#!/bin/bash
set -euxo pipefail

echo "Running custom install scripts..."
pacman-key --populate archlinux

# Enable multilib
cat <<EOF >> /etc/pacman.conf

[multilib]
Include = /etc/pacman.d/mirrorlist
EOF
pacman -Syyu --noconfirm

shopt -s extglob
pacman -U /usr/src/paru/paru-bin-!(d*).pkg.tar.zst --noconfirm

# System
systemctl enable NetworkManager
systemctl enable systemd-timesyncd
pacman -S --noconfirm podman fuse-overlayfs

# Set up users
useradd -m -G wheel -s /bin/bash $USER
sed -i 's/# %wheel ALL=(ALL:ALL) ALL/%wheel ALL=(ALL:ALL) ALL/' /etc/sudoers
echo "source /etc/profile.d/trueline.sh" >> /home/$USER/.bashrc

echo "$USER:$PW" | chpasswd
pacman -S --noconfirm \
    btrfs-progs squashfs-tools cargo rust \
    baobab gdm gnome-backgrounds gnome-calculator gnome-calendar gnome-characters gnome-clocks gnome-color-manager gnome-connections gnome-console gnome-control-center gnome-disk-utility gnome-font-viewer gnome-keyring gnome-logs gnome-remote-desktop gnome-session gnome-settings-daemon gnome-shell gnome-shell-extensions gnome-text-editor gnome-user-share gnome-weather gvfs gvfs-google loupe nautilus snapshot sushi xdg-desktop-portal-gnome totem \
    rustup reflector nano nvidia-utils lib32-nvidia-utils noto-fonts ttf-firacode-nerd \
    firefox discord steam pika-backup mission-center krita obsidian
systemctl enable gdm

# Gnome extensions
mkdir -p /etc/dconf/profile
mkdir -p /etc/dconf/db/local.d

cat <<EOF > /etc/dconf/profile/user
user-db:user
system-db:local
EOF

dconf update

mkdir -p /root/extensions
cd /root/extensions
wget -c https://extensions.gnome.org/extension-data/blur-my-shellaunetx.v67.shell-extension.zip
wget -c https://extensions.gnome.org/extension-data/color-pickertuberry.v45.shell-extension.zip
wget -c https://extensions.gnome.org/extension-data/caffeinepatapon.info.v55.shell-extension.zip
gnome-extensions install blur-my-shellaunetx.v67.shell-extension.zip
gnome-extensions install color-pickertuberry.v45.shell-extension.zip
gnome-extensions install caffeinepatapon.info.v55.shell-extension.zip

chmod -R 755 /root/.local/share/gnome-shell/extensions/*
chown -R root:root /root/.local/share/gnome-shell/extensions/*
mv /root/.local/share/gnome-shell/extensions/* /usr/share/gnome-shell/extensions
rm -r /root/extensions

# System links
mkdir -p /home/$USER/Data

ln -s /home/$USER/Data/Documents /home/$USER/Documents
ln -s /home/$USER/Data/Games /home/$USER/Games
ln -s /home/$USER/Data/Music /home/$USER/Music
ln -s /home/$USER/Data/Scripts /home/$USER/Scripts
ln -s /home/$USER/Data/Pictures /home/$USER/Pictures
ln -s /home/$USER/Data/Videos /home/$USER/Videos

mkdir -p /home/$USER/.config/StardewValley
ln -s /home/$USER/Games/Stardew\ Valley /home/$USER/.config/StardewValley/Saves
mkdir -p /home/$USER/.config/unity3d/Klei
ln -s /home/$USER/Games/Oxygen\ Not\ Included /home/$USER/.config/unity3d/Klei/OxygenNotIncluded
mkdir -p /home/$USER/.config/unity3d/Team\ Cherry
ln -s /home/$USER/Games/Hollow\ Knight /home/$USER/.config/unity3d/Team\ Cherry/Hollow\ Knight
mkdir -p /home/$USER/.local/share
ln -s /home/$USER/Games/Terraria /home/$USER/.local/share/Terraria
mkdir -p /home/$USER
ln -s /home/$USER/Games/Factorio /home/$USER/.factorio
mkdir -p /home/$USER/.local/share/Steam/steamapps/common/Cuphead
ln -s /home/$USER/Games/Cuphead /home/$USER/.local/share/Steam/steamapps/common/Cuphead/Saves

mkdir -p /home/$USER/.config
ln -s /home/$USER/Data/AppData/vscode /home/$USER/.config/Code
ln -s /home/$USER/Data/AppData/discord /home/$USER/.config/discord
ln -s /home/$USER/Data/AppData/firefox /home/$USER/.mozilla
ln -s /home/$USER/Data/AppData/obsidian /home/$USER/.config/obsidian
mkdir -p /home/$USER/.local/share
ln -s /home/$USER/Data/AppData/steam /home/$USER/.local/share/.steam

ln -s /var/cache/pacman/pkg /usr/src/system/cache

# Hide extra desktop entries
mkdir -p /home/$USER/.local/share/applications
sed 's/\[Desktop Entry\]/\[Desktop Entry\]\nHidden=true/' /usr/share/applications/avahi-discover.desktop > /home/$USER/.local/share/applications/avahi-discover.desktop
sed 's/\[Desktop Entry\]/\[Desktop Entry\]\nHidden=true/' /usr/share/applications/bssh.desktop > /home/$USER/.local/share/applications/bssh.desktop
sed 's/\[Desktop Entry\]/\[Desktop Entry\]\nHidden=true/' /usr/share/applications/bvnc.desktop > /home/$USER/.local/share/applications/bvnc.desktop
# sed 's/\[Desktop Entry\]/\[Desktop Entry\]\nHidden=true/' /usr/share/applications/electron32.desktop > /home/$USER/.local/share/applications/electron32.desktop
sed 's/\[Desktop Entry\]/\[Desktop Entry\]\nHidden=true/' /usr/share/applications/qv4l2.desktop > /home/$USER/.local/share/applications/qv4l2.desktop
sed 's/\[Desktop Entry\]/\[Desktop Entry\]\nHidden=true/' /usr/share/applications/qvidcap.desktop > /home/$USER/.local/share/applications/qvidcap.desktop
