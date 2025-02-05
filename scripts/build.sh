#!/bin/bash
set -e

pacstrap -cKNP /mnt base base-devel linux linux-firmware grub efibootmgr nano git networkmanager
cp /scripts/initramfs_overlay_hook /mnt/etc/initcpio/hooks/overlay_root
cp /scripts/initramfs_overlay_install /mnt/etc/initcpio/install/overlay_root
sed -i 's/^\(HOOKS=.*fsck\))/\1 overlay_root)/' /mnt/etc/mkinitcpio.conf
cp /scripts/profile.sh /mnt

mkdir -p /mnt/var/cache/pacman
mount --bind /var/cache/pacman/pkg /mnt/var/cache/pacman/pkg

mount -t proc /proc /mnt/proc
mount -t sysfs /sys /mnt/sys
mount -o bind /dev /mnt/dev
cp /etc/resolv.conf /mnt/etc/resolv.conf

chroot /mnt /bin/bash /profile.sh

umount -l /mnt/var/cache/pacman/pkg
umount -l /mnt/proc
umount -l /mnt/sys
umount -l /mnt/dev

mksquashfs /mnt /arch.sqfs
