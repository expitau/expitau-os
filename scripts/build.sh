#!/bin/bash
set -euxo pipefail

# Set USER variable if not set, this comes from build script. Default password is not a secret
USER=${USER:-user}
PW=$(echo "${PW:-cGFzc3dvcmQ=}" | base64 --decode)

# Install base system and packages required for setup (remaining packages will be installed as part of setup)
pacstrap -cKNP /mnt base base-devel linux linux-firmware linux-headers sof-firmware git networkmanager wget

# Configure mkinitcpio to generate UKI images
cp /scripts/config/linux.preset /mnt/etc/mkinitcpio.d/linux.preset
cp /scripts/config/mkinitcpio.conf /mnt/etc/mkinitcpio.conf

# Copy fstab
cp /scripts/config/fstab /mnt/etc/fstab

# Copy desktop wallpaper
mkdir -p /mnt/usr/share/backgrounds/gnome
cp /scripts/config/wallpaper.png /mnt/usr/share/backgrounds/gnome/wallpaper.png

# Copy shell config
cp /scripts/config/trueline.sh /mnt/etc/profile.d/trueline.sh

# Copy dconf settings
mkdir -p /mnt/etc/dconf/db/local.d
mv /scripts/config/dconf.conf /mnt/etc/dconf/db/local.d/00-profile

# Copy paru source code
cp paru/ /mnt/usr/src/paru -r

# Copy system source code
cp -r /src /mnt/usr/src/system
cp /src/system/target/release/system /mnt/usr/local/sbin/system

# Copy pacman cache
# The package cache will be baked in to the image, so it will be available already after installation
# The cache will then be copied back to the host, so it can be reused for the next build
mkdir -p /mnt/var/cache/pacman/pkg
cp -R /var/cache/pacman/pkg/* /mnt/var/cache/pacman/pkg

# Setup mounts (because we aren't using arch-chroot)
mount -t proc /proc /mnt/proc
mount -t sysfs /sys /mnt/sys
mount -o bind /dev /mnt/dev
cp /scripts/setup.sh /mnt/setup.sh
cp /etc/resolv.conf /mnt/etc/resolv.conf

# Run setup script in chroot
# These variables are passed in podman run with --env USER=username --env PW=password
chroot /mnt env USER=$USER PW=$PW /bin/bash /setup.sh

# Cleanup
cp -R /mnt/var/cache/pacman/pkg/* /var/cache/pacman/pkg
umount -l /mnt/proc
umount -l /mnt/sys
umount -l /mnt/dev
rm /mnt/setup.sh

mkdir -p /mnt/efi

# Create image
mksquashfs /mnt /arch.sqfs
