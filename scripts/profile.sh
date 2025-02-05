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
sed -i 's/# %wheel ALL=(ALL) ALL/%wheel ALL=(ALL) ALL/' /etc/sudoers

echo "nathan:test" | chpasswd
pacman -S --noconfirm \
    baobab gdm gnome-backgrounds gnome-calculator gnome-calendar gnome-characters gnome-clocks gnome-color-manager gnome-connections gnome-console gnome-control-center gnome-disk-utility gnome-font-viewer gnome-keyring gnome-logs gnome-remote-desktop gnome-session gnome-settings-daemon gnome-shell gnome-shell-extensions gnome-text-editor gnome-user-docs gnome-user-share gnome-weather gvfs gvfs-google loupe nautilus snapshot sushi xdg-desktop-portal-gnome totem \
    code discord
systemctl enable gdm

# Gnome extensions
