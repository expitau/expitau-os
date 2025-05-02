#!/bin/bash
set -euxo pipefail

# === 1. Setup user account === #

# Create user, enable sudo
set +x
useradd -m -G wheel -s /bin/bash -p $(echo $SYSTEM_PW | base64 -d) $SYSTEM_USER
set -x

sed -i 's/# %wheel ALL=(ALL:ALL) ALL/%wheel ALL=(ALL:ALL) ALL/' /etc/sudoers
echo "source /etc/profile.d/trueline.sh" >> /home/$SYSTEM_USER/.bashrc
export USER=$SYSTEM_USER

# === 2. Update system, install packages === #

# Enable multilib for steam
cat <<EOF >> /etc/pacman.conf

[multilib]
Include = /etc/pacman.d/mirrorlist
EOF

# Update system
pacman-key --populate archlinux
pacman -Syyu --noconfirm

# Install gnome, system utilities, and apps
pacman -S --noconfirm \
    baobab gdm gnome-backgrounds gnome-calculator gnome-calendar gnome-characters gnome-clocks gnome-color-manager gnome-connections gnome-console gnome-control-center gnome-disk-utility gnome-font-viewer gnome-keyring gnome-logs gnome-remote-desktop gnome-session gnome-settings-daemon gnome-shell gnome-shell-extensions gnome-text-editor gnome-user-share gnome-weather gvfs gvfs-google loupe nautilus snapshot sushi xdg-desktop-portal-gnome totem \
    btrfs-progs squashfs-tools rust podman fuse-overlayfs \
    reflector nano noto-fonts ttf-firacode-nerd fastfetch whois \
    bluez bluez-utils inotify-tools fprintd power-profiles-daemon \
    libvirt qemu-base virt-manager \
    nvidia-open-dkms nvidia-utils lib32-nvidia-utils apparmor nftables intel-ucode \
    firefox discord steam pika-backup mission-center krita obsidian

# Install AUR packages
mkdir -p /tmp/aur
chown nobody:nobody /tmp/aur
chmod 644 /etc/pacman.conf
for pkg in paru-bin visual-studio-code-bin; do
    sudo -u nobody -- git clone https://aur.archlinux.org/$pkg.git /tmp/aur/$pkg --depth 1
    sudo -u nobody -- makepkg -D /tmp/aur/$pkg
done

pacman -U $(find /tmp/aur -type f -name "*.pkg.tar.zst" ! -name "*debug*" -print) --noconfirm

# Enable system services
systemctl enable NetworkManager
systemctl enable systemd-timesyncd
systemctl enable bluetooth
systemctl enable apparmor
systemctl enable nftables
systemctl enable gdm

mkinitcpio -P

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
wget -c https://extensions.gnome.org/extension-data/blur-my-shellaunetx.v68.shell-extension.zip
wget -c https://extensions.gnome.org/extension-data/color-pickertuberry.v45.shell-extension.zip
wget -c https://extensions.gnome.org/extension-data/caffeinepatapon.info.v56.shell-extension.zip
gnome-extensions install blur-my-shellaunetx.v68.shell-extension.zip
gnome-extensions install color-pickertuberry.v45.shell-extension.zip
gnome-extensions install caffeinepatapon.info.v56.shell-extension.zip

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

# === 4. System links and cleanup === #
ln -s /var/cache/pacman/pkg /usr/src/system/cache
rm -r /etc/NetworkManager/system-connections
ln -s /home/nathan/Data/AppData/system/networkmanager /etc/NetworkManager/system-connections

# Fix permissions
mkdir -p /home/nathan/Data
chown $USER:$USER /home/nathan/Data
chmod 644 /etc/pacman.conf

# Cleanup pacman cache
pacman -Sc --noconfirm
