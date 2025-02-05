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
8. Mount btrfs and create subvolumes
    - `mount /dev/vda2 /mnt`
    - `btrfs subvolume create /mnt/@`
    - `btrfs subvolume create /mnt/@data`
    - `umount /mnt`
