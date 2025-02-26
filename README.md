# Installation steps:

1. Update repo and keyring `pacman -Sy && pacman -S archlinux-keyring`
2. Install dependencies `pacman -S git wget`
5. Create disk partitions. Make a 1G EFI partition and another partition that uses the rest. `cfdisk`
6. Format the EFI partition as vfat `mkfs.vfat /dev/vda1`
7. Format the rest as btrfs `mkfs.btrfs /dev/vda2`
8. Label the btrfs partition "arch" `btrfs filesystem label /dev/vda2 arch`
9. Mount btrfs and create subvolumes
    - `mount /dev/vda2 /mnt`
    - `btrfs subvolume create /mnt/@`
    - `btrfs subvolume create /mnt/@data`
3. Make temporary subvolume `btrfs subvolume create /mnt/@tmp`
10. Get a copy of arch.sqfs `cd /mnt/@tmp && curl https://raw.githubusercontent.com/expitau/System/refs/heads/main/create_image.sh | sh`
11. Unpack the squashfs to new root subvolume
    - `unsquashfs -d /mnt/@ /mnt/@tmp/arch.sqfs`
12. Mount efi partition and install bootloader
    - `mount /dev/vda1 /mnt/@/efi`
    - `bootctl install --esp-path=/mnt/@/efi`


## TODO
- [ ] Implement pretty list snapshots
- [ ] Get most recent rollback snapshot *in current branch*
    - [ ] Get current branch function
- [ ] Finish migrate command
    - [ ] Make initial migrate read-only
- [x] Implement lock and unlock
- [ ] Implement UKI pinning
- [ ] Implement deletion
