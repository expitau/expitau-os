#!/bin/bash
set -e

echo "Running custom install scripts..."
pacman-key --populate archlinux

# System
systemctl enable NetworkManager
systemctl enable systemd-timesyncd
pacman -S --noconfirm podman fuse-overlayfs

# Set up users
useradd -m -G wheel -s /bin/bash nathan
sed -i 's/# %wheel ALL=(ALL:ALL) ALL/%wheel ALL=(ALL:ALL) ALL/' /etc/sudoers

echo "nathan:test" | chpasswd
pacman -S --noconfirm \
    btrfs-progs squashfs-tools cargo rust \
    baobab gdm gnome-backgrounds gnome-calculator gnome-calendar gnome-characters gnome-clocks gnome-color-manager gnome-connections gnome-console gnome-control-center gnome-disk-utility gnome-font-viewer gnome-keyring gnome-logs gnome-remote-desktop gnome-session gnome-settings-daemon gnome-shell gnome-shell-extensions gnome-text-editor gnome-user-docs gnome-user-share gnome-weather gvfs gvfs-google loupe nautilus snapshot sushi xdg-desktop-portal-gnome totem \
    code discord
systemctl enable gdm

# Gnome extensions
mkdir -p /etc/dconf/profile
mkdir -p /etc/dconf/db/local.d

cat <<EOF > /etc/dconf/profile/user
user-db:user
system-db:local
EOF

cat <<EOF > /etc/dconf/db/local.d/00-profile
[org/gnome/desktop/background]
picture-uri='file:///usr/share/backgrounds/gnome/night.jpg'
picture-uri-dark='file:///usr/share/backgrounds/gnome/night.jpg'

[org/gnome/desktop/screensaver]
picture-uri='file:///usr/share/backgrounds/gnome/night.jpg'
picture-uri-dark='file:///usr/share/backgrounds/gnome/night.jpg'

[org/gnome/desktop/interface]
color-scheme='prefer-dark'
clock-format='24h'

[org/gnome/shell/extensions/color-picker]
color-picker-shortcut=['<Shift><Super>c']
enable-preview=true
enable-shortcut=true
enable-sound=false
enable-systray=false
format-menu=false

[org/gnome/shell]
enabled-extensions=['blur-my-shell@aunetx', 'color-picker@tuberry', 'caffeine@patapon.info']
favorite-apps=['firefox.desktop', 'org.gnome.Nautilus.desktop', 'org.gnome.TextEditor.desktop', 'code.desktop', 'org.gnome.Console.desktop', 'discord.desktop']
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
