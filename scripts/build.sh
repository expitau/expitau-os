#!/bin/bash
set -e

pacstrap -cKNP /mnt base base-devel linux linux-firmware grub efibootmgr nano git networkmanager wget

cp /scripts/config/linux.preset /mnt/etc/mkinitcpio.d/linux.preset
mkdir -p /mnt/usr/share/backgrounds/gnome
cp /scripts/config/Wallpaper.png /mnt/usr/share/backgrounds/gnome/chichien.png
cp /scripts/config/trueline.sh /mnt/etc/profile.d/trueline.sh
mkdir -p /mnt/etc/dconf/db/local.d/00-profile
mv /scripts/config/dconf.conf /mnt/etc/dconf/db/local.d/00-profile

cp paru/ /mnt/usr/src/paru -r

cp -r /src /mnt/usr/src/system
cp /src/system/target/release/system /mnt/usr/local/sbin/system

mkdir -p /mnt/var/cache/pacman/pkg
cp -R /var/cache/pacman/pkg/* /mnt/var/cache/pacman/pkg

mount -t proc /proc /mnt/proc
mount -t sysfs /sys /mnt/sys
mount -o bind /dev /mnt/dev
cp /etc/resolv.conf /mnt/etc/resolv.conf

# These variables are passed in podman run with --env USER=username --env PW=password
chroot /mnt env USER=$USER PW=$PW /bin/bash /profile.sh

cp -R /mnt/var/cache/pacman/pkg/* /var/cache/pacman/pkg
umount -l /mnt/proc
umount -l /mnt/sys
umount -l /mnt/dev

mksquashfs /mnt /arch.sqfs
