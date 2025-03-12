#!/bin/bash
set -euxo pipefail

# === 1. Update system, install packages === #

# Enable multilib for steam
cat <<EOF >> /etc/pacman.conf

[multilib]
Include = /etc/pacman.d/mirrorlist
EOF

# Update system
pacman-key --populate archlinux
pacman -Syyu --noconfirm

# Install AUR helper paru
shopt -s extglob # 
pacman -U --noconfirm /usr/src/paru/paru-bin-!(d*).pkg.tar.zst

# Install gnome, system utilities, and apps
pacman -S --noconfirm \
    baobab gdm gnome-backgrounds gnome-calculator gnome-calendar gnome-characters gnome-clocks gnome-color-manager gnome-connections gnome-console gnome-control-center gnome-disk-utility gnome-font-viewer gnome-keyring gnome-logs gnome-remote-desktop gnome-session gnome-settings-daemon gnome-shell gnome-shell-extensions gnome-text-editor gnome-user-share gnome-weather gvfs gvfs-google loupe nautilus snapshot sushi xdg-desktop-portal-gnome totem \
    btrfs-progs squashfs-tools rust podman fuse-overlayfs reflector nano noto-fonts ttf-firacode-nerd bluez bluez-utils inotify-tools fastfetch whois fprintd \
    nvidia-open-dkms nvidia-utils lib32-nvidia-utils apparmor nftables intel-ucode \
    firefox discord steam pika-backup mission-center krita obsidian

paru -S --noconfirm visual-studio-code-bin

# Enable system services
systemctl enable NetworkManager
systemctl enable systemd-timesyncd
systemctl enable bluetooth
systemctl enable apparmor
systemctl enable nftables
systemctl enable gdm

mkinitcpio -P

# === 2. Setup user account === #

# Create user, enable sudo
useradd -m -G wheel -s /bin/bash -p $SYSTEM_PW $SYSTEM_USER
sed -i 's/# %wheel ALL=(ALL:ALL) ALL/%wheel ALL=(ALL:ALL) ALL/' /etc/sudoers
echo "source /etc/profile.d/trueline.sh" >> /home/$SYSTEM_USER/.bashrc
export USER=$SYSTEM_USER

# === 3. Customization, gnome extensions, dconf settings === #

# Dconf settings
mkdir -p /etc/dconf/profile
mkdir -p /etc/dconf/db/local.d

cat <<EOF > /etc/dconf/profile/user
user-db:user
system-db:local
EOF
dconf update

# Download gnome extensions, install to root account temporarily
mkdir -p /root/extensions
cd /root/extensions
wget -c https://extensions.gnome.org/extension-data/blur-my-shellaunetx.v67.shell-extension.zip
wget -c https://extensions.gnome.org/extension-data/color-pickertuberry.v45.shell-extension.zip
wget -c https://extensions.gnome.org/extension-data/caffeinepatapon.info.v55.shell-extension.zip
gnome-extensions install blur-my-shellaunetx.v67.shell-extension.zip
gnome-extensions install color-pickertuberry.v45.shell-extension.zip
gnome-extensions install caffeinepatapon.info.v55.shell-extension.zip

# Install gnome extensions system-wide
chmod -R 755 /root/.local/share/gnome-shell/extensions/*
chown -R root:root /root/.local/share/gnome-shell/extensions/*
mv /root/.local/share/gnome-shell/extensions/* /usr/share/gnome-shell/extensions
rm -r /root/extensions

# Hide extra desktop entries
mkdir -p /home/$USER/.local/share/applications

for file in /usr/share/applications/{avahi-discover,bssh,bvnc,qv4l2,qvidcap,electron*}.desktop; do
    [ -f "$file" ] && sed 's/\[Desktop Entry\]/\[Desktop Entry\]\nHidden=true/' "$file" > "/home/$USER/.local/share/applications/$(basename "$file")"
done

# === 4. Setup home directory === #

# System links

mkdir -p /var/data

ln -s /var/data /home/$USER/Data

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

rm -r /usr/src/system/cache
ln -s /var/cache/pacman/pkg /usr/src/system/cache

pacman -Sc --noconfirm

# Fix permissions
chown -R $USER:$USER /home/$USER
chown -R $USER:$USER /var/data
chmod 644 /etc/pacman.conf
