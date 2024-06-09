#!/usr/bin/env bash
set -o errexit # Exit on non-zero status
set -o nounset # Error on unset variables

# [ENVIRONMENT]: OVERRIDE DEFAULTS

declare -g OSTREE_DEV_SCSI=[YOUR DEVICE HERE]

declare -g OSTREE_DEV_DISK="/dev/disk/by-id/[YOUR DEVICE HERE]"
declare -g OSTREE_DEV_BOOT="[YOUR DEVICE HERE]-part1"}
declare -g OSTREE_DEV_ROOT="[YOUR DEVICE HERE]-part2"}
declare -g OSTREE_DEV_HOME="[YOUR DEVICE HERE]-part3"}
declare -g OSTREE_SYS_ROOT='/tmp/chroot'}

declare -g OSTREE_SYS_ROOT='/'
declare -g OSTREE_SYS_TREE='/tmp/rootfs'
declare -g OSTREE_SYS_KARG=''
declare -g OSTREE_SYS_BOOT_LABEL='SYS_BOOT'
declare -g OSTREE_SYS_ROOT_LABEL='SYS_ROOT'
declare -g OSTREE_SYS_HOME_LABEL='SYS_HOME'
declare -g OSTREE_OPT_NOMERGE='--no-merge'
declare -g OSTREE_REP_NAME='archlinux'

declare -g SYSTEM_OPT_TIMEZONE='Etc/UTC'
declare -g SYSTEM_OPT_KEYMAP='us'

declare -g PACMAN_OPT_NOCACHE='0'

# [DISK]: PARTITIONING (GPT+UEFI)
pacman --noconfirm --sync --needed parted
mkdir -p '/tmp/chroot'
lsblk --noheadings --output='MOUNTPOINTS' | grep -w /tmp/chroot | xargs -r umount --lazy --verbose
parted -a optimal -s /dev/nvme0n1 -- \
    mklabel gpt \
    mkpart SYS_BOOT fat32 0% 257MiB \
    set 1 esp on \
    mkpart SYS_ROOT xfs 257MiB 25GiB \
    mkpart SYS_HOME xfs 25GiB 100%

# [DISK]: FILESYSTEM (ESP+XFS)
pacman -Sy --needed dosfstools xfsprogs
mkfs.vfat -n SYS_BOOT -F 32 /dev/nvme0n1p1
mkfs.xfs -L SYS_ROOT -f /dev/nvme0n1p2 -n ftype=1
mkfs.xfs -L SYS_HOME -f /dev/nvme0n1p3 -n ftype=1

# [DISK]: BUILD DIRECTORY
mount --mkdir /dev/nvme0n1p2 /tmp/chroot
mount --mkdir /dev/nvme0n1p1 /tmp/chroot/boot/efi

# [OSTREE]: FIRST INITIALIZATION
pacman -Sy --needed ostree which
ostree admin init-fs --sysroot="/tmp/chroot" --modern /tmp/chroot
ostree admin stateroot-init --sysroot="/tmp/chroot" archlinux
ostree init --repo="/tmp/chroot/ostree/repo" --mode='bare'
ostree config --repo="/tmp/chroot/ostree/repo" set sysroot.bootprefix 1

# [OSTREE]: BUILD ROOTFS
# Add support for overlay storage driver in LiveCD
pacman -Sy --needed fuse-overlayfs podman

mkdir -p "/tmp/podman/var/cache/pacman"

podman --root="/tmp/podman/storage" \
    --tmpdir="/tmp/podman/tmp" \
    build \
    --volume="/tmp/podman/var/cache/pacman:/tmp/podman/var/cache/pacman" \
    --file="./archlinux/Containerfile.base" \
    --tag="ostree/base" \
    --cap-add='SYS_ADMIN' \
    --build-arg="OSTREE_SYS_BOOT_LABEL=SYS_BOOT" \
    --build-arg="OSTREE_SYS_HOME_LABEL=SYS_HOME" \
    --build-arg="OSTREE_SYS_ROOT_LABEL=SYS_ROOT" \
    --build-arg="SYSTEM_OPT_TIMEZONE=Etc/UTC" \
    --build-arg="SYSTEM_OPT_KEYMAP=us" \
    --pull='newer'

podman --root="/tmp/podman/storage" \
    --tmpdir="/tmp/podman/tmp" \
    build \
    --volume="/tmp/podman/var/cache/pacman:/tmp/podman/var/cache/pacman" \
    --file="./Containerfile.host.example" \
    --tag="ostree/host" \
    --cap-add='SYS_ADMIN' \
    --build-arg="OSTREE_SYS_BOOT_LABEL=SYS_BOOT" \
    --build-arg="OSTREE_SYS_HOME_LABEL=SYS_HOME" \
    --build-arg="OSTREE_SYS_ROOT_LABEL=SYS_ROOT" \
    --build-arg="SYSTEM_OPT_TIMEZONE=Etc/UTC" \
    --build-arg="SYSTEM_OPT_KEYMAP=us" \
    --pull='newer'

# Ostreeify: retrieve rootfs (workaround: `podman build --output local` doesn't preserve ownership)
rm -rf /tmp/rootfs
mkdir -p /tmp/rootfs
podman --root="/tmp/podman/storage" --tmpdir="/tmp/podman/tmp" export $(podman --root="/tmp/podman/storage" --tmpdir="/tmp/podman/tmp" create ostree/host bash) | tar -xC /tmp/rootfs

# [OSTREE]: DIRECTORY STRUCTURE (https://ostree.readthedocs.io/en/stable/manual/adapting-existing)
# Doing it here allows the container to be runnable/debuggable and Containerfile reusable
mv /tmp/rootfs/etc /tmp/rootfs/usr/

rm -r /tmp/rootfs/home
ln -s var/home /tmp/rootfs/home

rm -r /tmp/rootfs/mnt
ln -s var/mnt /tmp/rootfs/mnt

rm -r /tmp/rootfs/opt
ln -s var/opt /tmp/rootfs/opt

rm -r /tmp/rootfs/root
ln -s var/roothome /tmp/rootfs/root

rm -r /tmp/rootfs/srv
ln -s var/srv /tmp/rootfs/srv

mkdir /tmp/rootfs/sysroot
ln -s sysroot/ostree /tmp/rootfs/ostree

rm -r /tmp/rootfs/usr/local
ln -s ../var/usrlocal /tmp/rootfs/usr/local

printf >&1 '%s\n' 'Creating tmpfiles'
echo 'd /var/home 0755 root root -' >> /tmp/rootfs/usr/lib/tmpfiles.d/ostree-0-integration.conf
echo 'd /var/lib 0755 root root -' >> /tmp/rootfs/usr/lib/tmpfiles.d/ostree-0-integration.conf
echo 'd /var/log/journal 0755 root root -' >> /tmp/rootfs/usr/lib/tmpfiles.d/ostree-0-integration.conf
echo 'd /var/mnt 0755 root root -' >> /tmp/rootfs/usr/lib/tmpfiles.d/ostree-0-integration.conf
echo 'd /var/opt 0755 root root -' >> /tmp/rootfs/usr/lib/tmpfiles.d/ostree-0-integration.conf
echo 'd /var/roothome 0700 root root -' >> /tmp/rootfs/usr/lib/tmpfiles.d/ostree-0-integration.conf
echo 'd /var/srv 0755 root root -' >> /tmp/rootfs/usr/lib/tmpfiles.d/ostree-0-integration.conf
echo 'd /var/usrlocal 0755 root root -' >> /tmp/rootfs/usr/lib/tmpfiles.d/ostree-0-integration.conf
echo 'd /var/usrlocal/bin 0755 root root -' >> /tmp/rootfs/usr/lib/tmpfiles.d/ostree-0-integration.conf
echo 'd /var/usrlocal/etc 0755 root root -' >> /tmp/rootfs/usr/lib/tmpfiles.d/ostree-0-integration.conf
echo 'd /var/usrlocal/games 0755 root root -' >> /tmp/rootfs/usr/lib/tmpfiles.d/ostree-0-integration.conf
echo 'd /var/usrlocal/include 0755 root root -' >> /tmp/rootfs/usr/lib/tmpfiles.d/ostree-0-integration.conf
echo 'd /var/usrlocal/lib 0755 root root -' >> /tmp/rootfs/usr/lib/tmpfiles.d/ostree-0-integration.conf
echo 'd /var/usrlocal/man 0755 root root -' >> /tmp/rootfs/usr/lib/tmpfiles.d/ostree-0-integration.conf
echo 'd /var/usrlocal/sbin 0755 root root -' >> /tmp/rootfs/usr/lib/tmpfiles.d/ostree-0-integration.conf
echo 'd /var/usrlocal/share 0755 root root -' >> /tmp/rootfs/usr/lib/tmpfiles.d/ostree-0-integration.conf
echo 'd /var/usrlocal/src 0755 root root -' >> /tmp/rootfs/usr/lib/tmpfiles.d/ostree-0-integration.conf
echo 'd /run/media 0755 root root -' >> /tmp/rootfs/usr/lib/tmpfiles.d/ostree-0-integration.conf

# Only retain information about Pacman packages in new rootfs
mv /tmp/rootfs/var/lib/pacman /tmp/rootfs/usr/lib/
sed -i \
    -e 's|^#\(DBPath\s*=\s*\).*|\1/usr/lib/pacman|g' \
    -e 's|^#\(IgnoreGroup\s*=\s*\).*|\1modified|g' \
    /tmp/rootfs/usr/etc/pacman.conf

# Allow Pacman to store update notice id during unlock mode
mkdir /tmp/rootfs/usr/lib/pacmanlocal

# OSTree mounts /ostree/deploy/${OSTREE_REP_NAME}/var to /var
rm -r /tmp/rootfs/var/*

# [OSTREE]: CREATE COMMIT
# Update repository and boot entries in GRUB2
ostree commit --repo="/tmp/chroot/ostree/repo" --branch="archlinux/latest" --tree=dir="/tmp/rootfs"
ostree admin deploy --sysroot="/tmp/chroot" --karg="root=LABEL=SYS_ROOT rw" --os="archlinux" --no-merge --retain archlinux/latest

# [BOOTLOADER]: FIRST BOOT
# | Todo: improve grub-mkconfig
grub-install --target='x86_64-efi' --efi-directory="/tmp/chroot/boot/efi" --boot-directory="/tmp/chroot/boot/efi/EFI" --bootloader-id="archlinux" --removable /dev/nvme0n1p1

local OSTREE_SYS_PATH=$(ls -d /tmp/chroot/ostree/deploy/archlinux/deploy/* | head -n 1)

rm -rfv ${OSTREE_SYS_PATH}/boot/*
mount --mkdir --rbind /tmp/chroot/boot ${OSTREE_SYS_PATH}/boot
mount --mkdir --rbind /tmp/chroot/ostree ${OSTREE_SYS_PATH}/sysroot/ostree

for i in /dev /proc /sys; do mount -o bind $i ${OSTREE_SYS_PATH}${i}; done
chroot ${OSTREE_SYS_PATH} /bin/bash -c 'grub-mkconfig -o /boot/efi/EFI/grub/grub.cfg'

umount --recursive /tmp/chroot



OSTREE_CREATE_REPO
OSTREE_CREATE_ROOTFS
OSTREE_CREATE_LAYOUT
OSTREE_DEPLOY_IMAGE

BOOTLOADER_CREATE
