#!/bin/bash
set -e

pacstrap -cKNP /mnt base base-devel linux linux-firmware grub efibootmgr nano git networkmanager wget

cp /scripts/linux.preset /mnt/etc/mkinitcpio.d/linux.preset
cp /scripts/profile.sh /mnt
mkdir -p /mnt/usr/share/backgrounds/gnome
cp /scripts/Wallpaper.png /mnt/usr/share/backgrounds/gnome/chichien.png

mkdir -p /mnt/etc/dconf/db/local.d/00-profile
mv /scripts/dconf.conf /mnt/etc/dconf/db/local.d/00-profile

cp -r /src /mnt/usr/src/system
cp /src/target/release/system /mnt/usr/local/sbin/system

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
