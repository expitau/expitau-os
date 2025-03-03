## Installation

1. Download and run an [Arch Linux ISO](https://archlinux.org/download/)
2. Install necessary dependencies for installation
    - `pacman -Sy`
    - `pacman -S archlinux-keyring`
    - `pacman -S git wget`
3. Create disk partition layout. **Labels must be exact** (change this in scripts/config/fstab and system/src/entry.conf)
    - `cfdisk`
    - `mkfs.vfat /dev/<disk>p1` `mkfs.btrfs /dev/<disk>p2`
    - `dosfslabel /dev/<disk>p1 ARCH_BOOT`
    - `btrfs filesystem label /dev/<disk>p2 ARCH_ROOT`
```
<disk>
├─<disk>p1  ARCH_BOOT  1G    vfat
└─<disk>p2  ARCH_ROOT  100%  btrfs
```
4. Mount btrfs and create subvolumes
    - `mount /dev/<disk>p2 /mnt`
    - `btrfs subvolume create /mnt/@root`
    - `btrfs subvolume create /mnt/@tmp`
    - `btrfs subvolume create /mnt/data`

5. Download squashfs image
    - `cd /mnt/@tmp && curl https://raw.githubusercontent.com/expitau/System/refs/heads/main/create_image.sh | sh`

6. Unpack the squashfs to root subvolume
    - `unsquashfs -d /mnt/@ /mnt/@tmp/arch.sqfs`

7. Mount efi partition and install bootloader
    - `mount /dev/<disk>p1 /mnt/@/efi`
    - `bootctl install --esp-path=/mnt/@/efi`
    - `cp /mnt/@/usr/lib/kernel/arch-linux.efi /mnt/@/efi/EFI/Arch/arch-linux.efi`

## How it works

### 1. Transport mechanism

### 2. Build process

**TODO**
- The system is generated via a docker container. The definition is in the root Dockerfile
- When this dockerfile is run, it generates a file arch.sqfs in the root directory. This is the system image
- The system image is copied to the host, split into chunks, and published as a release

### 3. Runtime

**TODO**
- There are two main components to the operating system, the efi binary and the root filesystem
- The efi binary is a single file arch-linux.efi, which contains the linux kernel, the initramfs, and microcode. It is responsible for mounting the root filesystem. It resides in the boot partition
- The root filesystem contains all of the packages and configuration. It resides in a btrfs subvolume.
- On boot, a kernel parameter `rootflags=subvol=@my-subvolume` is passed (or default is used), which specifies which subvolume to mount. The efi binaries are sourced by systemd boot entries, and are located at `/usr/lib/kernel/arch-linux.efi` for each image, and copied to the boot folder when needed.
