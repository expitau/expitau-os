**The pieces**
- mkinitcpio is able to build UKI images that contain either systemd or busybox. Saves to /efi/*.efi
- systemd-boot is able to boot .efi images, and is entirely stored in /efi
- My initramfs hook runs on busybox, and mounts the overlayfs correctly.


# Installation steps:

1. Update repo and keyring `pacman -Sy && pacman -S archlinux-keyring`
2. Allocate additional space to arch ISO `mount -o remount,size=6G /run/archiso/cowspace`
3. Install dependencies `pacman -S git podman fuse-overlayfs shadow glibc`
4. Clone the repository `git clone https://github.com/expitau/System`
5. Create disk partitions. Make a 1G EFI partition and another partition that uses the rest. `cfdisk`
6. Format the EFI partition as vfat `mkfs.vfat /dev/vda1`
7. Format the rest as btrfs `mkfs.btrfs /dev/vda2`
8. Label the btrfs partition "arch" `btrfs filesystem label /dev/vda2 arch`
9. Mount btrfs and create subvolumes
    - `mount /dev/vda2 /mnt`
    - `btrfs subvolume create /mnt/@`
    - `btrfs subvolume create /mnt/@data`
    - `umount /mnt`
10. Get a copy of arch.sqfs `cd tmp && curl https://raw.githubusercontent.com/expitau/System/refs/heads/main/create_image.sh | sh`
11. Unpack the squashfs to new root subvolume
    - `mount /dev/vda2 -o subvol=@ /mnt`
    - `unsquashfs -d /mnt /tmp/arch.sqfs`
12. Mount efi partition and install bootloader
    - `mount /dev/vda1 /mnt/efi`
    - `bootctl install --efi-path=/mnt/efi`
