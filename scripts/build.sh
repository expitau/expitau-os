#!/bin/bash
set -e

pacstrap -cKNP /mnt base base-devel linux linux-firmware grub efibootmgr nano git networkmanager
cp /scripts/initramfs_overlay_hook /mnt/etc/initcpio/hooks/overlay_root
cp /scripts/initramfs_overlay_install /mnt/etc/initcpio/install/overlay_root
sed -i 's/^\(HOOKS=.*fsck\))/\1 overlay_root)/' /mnt/etc/mkinitcpio.conf
cp /scripts/profile.sh /mnt

mkdir -p /mnt/var/cache/pacman
ln -s /var/cache/pacman/pkg /mnt/var/cache/pacman/pkg

arch-chroot -N /mnt /bin/bash /profile.sh

mksquashfs /mnt /arch.sqfs
