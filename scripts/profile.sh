#!/bin/bash
set -e

echo "Running custom install scripts..."
pacman-key --populate archlinux
systemctl enable NetworkManager
systemctl enable systemd-timesyncd
pacman -S --noconfirm podman fuse-overlayfs
echo "root:test2" | chpasswd
pacman -S --noconfirm gnome
# systemctl enable gdm
