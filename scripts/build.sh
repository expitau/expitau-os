#!/bin/bash
set -euxo pipefail

# Set USER variable if not set, this comes from build script. Default password is not a secret
SYSTEM_USER=${SYSTEM_USER:-user}
SYSTEM_PW=${SYSTEM_PW:-JHkkajlUJFI3V3dTdVYxbEsxTWdhWlFlVjBsbzAkTkMyaTNjd2ovZnVvZE84UXN4NlptblFWaWhFeE1sa0xjV0dWcmw3UGRyNgo=}

# Install base system and packages required for setup (remaining packages will be installed as part of setup)
pacstrap -cKNP /mnt base base-devel linux linux-firmware linux-headers sof-firmware git networkmanager wget

# Configure mkinitcpio to generate UKI images
cp /scripts/config/linux.preset /mnt/etc/mkinitcpio.d/linux.preset
cp /scripts/config/mkinitcpio.conf /mnt/etc/mkinitcpio.conf

# Copy fstab
cp /scripts/config/fstab /mnt/etc/fstab

# Copy nftables
cp /scripts/config/nftables.conf /mnt/etc/nftables.conf

# Copy tmpfile
sed "s/\$USER/$SYSTEM_USER/g" /scripts/config/data-tmpfile.conf > /mnt/etc/tmpfiles.d/00-data.conf

# Copy desktop wallpaper
mkdir -p /mnt/usr/share/backgrounds/gnome
cp /scripts/config/wallpaper.png /mnt/usr/share/backgrounds/gnome/wallpaper.png

# Set user profile picture
mkdir -p /mnt/var/lib/AccountsService/{icons,users}
cp /scripts/config/icon.png /mnt/var/lib/AccountsService/icons/$SYSTEM_USER.png
cat <<EOF > /mnt/var/lib/AccountsService/users/$SYSTEM_USER
[User]
Session=
Icon=/var/lib/AccountsService/icons/$SYSTEM_USER
SystemAccount=false
EOF

# Copy shell config
cp /scripts/config/trueline.sh /mnt/etc/profile.d/trueline.sh

# Copy dconf settings
mkdir -p /mnt/etc/dconf/db/local.d
mv /scripts/config/dconf.conf /mnt/etc/dconf/db/local.d/00-profile

# Copy system source code
cp -r /src /mnt/usr/src/system
cp /src/system/target/release/system /mnt/usr/local/sbin/system

cat <<EOF > /mnt/usr/src/system/.env
SYSTEM_USER=$SYSTEM_USER

# Encode: mkpasswd "password" | base64
# Decode: echo "ENCODED" | base64 -d
SYSTEM_PW=$SYSTEM_PW
EOF

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
# These variables are passed in podman run with --env SYSTEM_USER=username --env SYSTEM_PW=password
chroot /mnt env SYSTEM_USER=$SYSTEM_USER SYSTEM_PW=$SYSTEM_PW /bin/bash /setup.sh

# Cleanup
cp -R /mnt/var/cache/pacman/pkg/* /var/cache/pacman/pkg
umount -l /mnt/proc
umount -l /mnt/sys
umount -l /mnt/dev
rm /mnt/setup.sh

mkdir -p /mnt/efi

# Create image
mksquashfs /mnt /arch.sqfs
cp /mnt/usr/lib/kernel/arch-linux.efi /arch-linux.efi
