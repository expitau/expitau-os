#!/bin/bash

echo "root:0:1000" >> /etc/subuid
echo "root:0:1000" >> /etc/subgid
pacstrap -KNP /mnt base base-devel linux linux-firmware grub efibootmgr nano git networkmanager
cp /scripts/initramfs_overlay_hook /mnt/etc/initcpio/hooks/overlay_root
cp /scripts/initramfs_overlay_install /mnt/etc/initcpio/install/overlay_root
sed -i 's/^\(HOOKS=.*fsck\))/\1 overlay_root)/' /mnt/etc/mkinitcpio.conf

arch-chroot -N /mnt /bin/bash <<'EOF'
mkinitcpio -P
systemctl enable NetworkManager
systemctl enable systemd-timesyncd
pacman -S --noconfirm podman fuse-overlayfs
echo "root:test2" | chpasswd
pacman -S --noconfirm gnome
# systemctl enable gdm
EOF

mksquashfs /mnt /arch.sqfs
