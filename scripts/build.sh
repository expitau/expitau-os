#!/bin/bash
set -euxo pipefail

# Install base system and packages required for setup (remaining packages will be installed as part of setup)
pacstrap -cKP /mnt base base-devel linux linux-firmware linux-headers sof-firmware git networkmanager wget

# Configure mkinitcpio to generate UKI images
cp /scripts/config/linux.preset /mnt/etc/mkinitcpio.d/linux.preset
cp /scripts/config/mkinitcpio.conf /mnt/etc/mkinitcpio.conf

# Copy example boot entry
cp /scripts/config/boot-entry.conf /mnt/etc/boot-entry.conf

# Copy fstab
cp /scripts/config/fstab /mnt/etc/fstab

# Copy nftables
cp /scripts/config/nftables.conf /mnt/etc/nftables.conf

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

# Copy tmpfile
sed "s/\$USER/$SYSTEM_USER/g" /scripts/config/data-tmpfile.conf > /mnt/etc/tmpfiles.d/00-data.conf

mkdir -p /mnt/efi
