# |
# | ROOTFS
# |

# Build a clean system in /mnt to avoid missing files from NoExtract option in upstream
FROM docker.io/archlinux/archlinux:latest AS rootfs

# Build in chroot to correctly execute hooks, this uses host's Pacman
RUN curl https://raw.githubusercontent.com/archlinux/svntogit-packages/packages/pacman/trunk/pacman.conf -o /etc/pacman.conf \
    && pacman --noconfirm --sync --needed --refresh archlinux-keyring

# Perform a clean system installation with latest Arch Linux packages in chroot to correctly execute hooks, this uses host's Pacman
RUN pacman --noconfirm --sync --needed arch-install-scripts \
    && pacstrap -K -P /mnt base base-devel linux linux-headers linux-firmware intel-ucode btrfs-progs grub mkinitcpio \
    && cp -av /etc/pacman.d/ /mnt/etc/

# |
# | BASE
# |

# Reusable base template
FROM scratch AS base
COPY --from=rootfs /mnt /

# Clock
ARG SYSTEM_OPT_TIMEZONE="Etc/UTC"
RUN ln --symbolic --force /usr/share/zoneinfo/${SYSTEM_OPT_TIMEZONE} /etc/localtime

# Keymap hook
ARG SYSTEM_OPT_KEYMAP="us"
RUN echo "KEYMAP=${SYSTEM_OPT_KEYMAP}" > /etc/vconsole.conf

# Language
RUN echo 'LANG=en_US.UTF-8' > /etc/locale.conf \
    && echo 'en_US.UTF-8 UTF-8' > /etc/locale.gen \
    && locale-gen

# Prepre OSTree integration (https://wiki.archlinux.org/title/Mkinitcpio#Common_hooks)
RUN mkdir -p /etc/mkinitcpio.conf.d \
    && echo "HOOKS=(base systemd ostree autodetect modconf kms keyboard sd-vconsole block encrypt btrfs filesystems fsck)" > /etc/mkinitcpio.conf.d/ostree.conf

# Install kernel, firmware, microcode, filesystem tools, bootloader & ostree and run hooks once:
RUN pacman --noconfirm --sync podman ostree which git networkmanager

# OSTree: Prepare microcode and initramfs
RUN moduledir=$(find /usr/lib/modules -mindepth 1 -maxdepth 1 -type d) && \
    cat /boot/*-ucode.img /boot/initramfs-linux-fallback.img > ${moduledir}/initramfs.img

# OSTree: Bootloader integration
RUN cp /usr/lib/libostree/* /etc/grub.d && chmod +x /etc/grub.d/15_ostree

# Podman: native Overlay Diff for optimal Podman performance
RUN echo "options overlay metacopy=off redirect_dir=off" > /etc/modprobe.d/disable-overlay-redirect-dir.conf

# Mount disk locations
ARG OSTREE_SYS_BOOT_LABEL="SYS_BOOT"
ARG OSTREE_SYS_ROOT_LABEL="fedora_fedora"
ARG OSTREE_SYS_EFI_LABEL="SYS_EFI"
RUN echo "LABEL=${OSTREE_SYS_ROOT_LABEL} / btrfs rw,relatime,noatime,subvol=root 0 0" >> /etc/fstab \
    && echo "LABEL=${OSTREE_SYS_BOOT_LABEL} /boot ext4 defaults 1 2" >> /etc/fstab \
    && echo "LABEL=${OSTREE_SYS_EFI_LABEL} /boot/efi vfat rw,relatime,fmask=0022,dmask=0022,codepage=437,iocharset=ascii,shortname=mixed,utf8,errors=remount-ro 0 2" >> /etc/fstab

# Networking
RUN pacman --noconfirm --sync networkmanager \
    && systemctl enable NetworkManager.service \
    && systemctl mask systemd-networkd-wait-online.service

# Root password
RUN echo "root:ostree" | chpasswd

# Add user
ARG USER="nathan"
RUN groupadd -g $GID -o $USER && \
    useradd -m -u $UID -g $GID -o $USER && \
    echo "$USER:$USER" | chpasswd && \
    echo "$USER ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/$USER && \
    # usermod -aG docker $USER && \
    # Create home directory
    touch /home/$USER && \
    chown $USER:$USER /home/$USER

RUN echo "My custom ostree stuff" > /myfile

RUN pacman --noconfirm -S gnome && \
    systemctl enable gdm.service

RUN mv /etc /usr/ && \
    rm -r /home && \
    ln -s var/home /home && \
    rm -r /mnt && \
    ln -s var/mnt /mnt && \
    rm -r /opt && \
    ln -s var/opt /opt && \
    rm -r /root && \
    ln -s var/roothome /root && \
    rm -r /srv && \
    ln -s var/srv /srv && \
    mkdir /sysroot && \
    ln -s sysroot/ostree /ostree && \
    rm -r /usr/local && \
    ln -s ../var/usrlocal /usr/local && \
    echo 'd /var/home 0755 root root -' >> /usr/lib/tmpfiles.d/ostree-0-integration.conf && \
    echo 'd /var/lib 0755 root root -' >> /usr/lib/tmpfiles.d/ostree-0-integration.conf && \
    echo 'd /var/log/journal 0755 root root -' >> /usr/lib/tmpfiles.d/ostree-0-integration.conf && \
    echo 'd /var/mnt 0755 root root -' >> /usr/lib/tmpfiles.d/ostree-0-integration.conf && \
    echo 'd /var/opt 0755 root root -' >> /usr/lib/tmpfiles.d/ostree-0-integration.conf && \
    echo 'd /var/roothome 0700 root root -' >> /usr/lib/tmpfiles.d/ostree-0-integration.conf && \
    echo 'd /var/srv 0755 root root -' >> /usr/lib/tmpfiles.d/ostree-0-integration.conf && \
    echo 'd /var/usrlocal 0755 root root -' >> /usr/lib/tmpfiles.d/ostree-0-integration.conf && \
    echo 'd /var/usrlocal/bin 0755 root root -' >> /usr/lib/tmpfiles.d/ostree-0-integration.conf && \
    echo 'd /var/usrlocal/etc 0755 root root -' >> /usr/lib/tmpfiles.d/ostree-0-integration.conf && \
    echo 'd /var/usrlocal/games 0755 root root -' >> /usr/lib/tmpfiles.d/ostree-0-integration.conf && \
    echo 'd /var/usrlocal/include 0755 root root -' >> /usr/lib/tmpfiles.d/ostree-0-integration.conf && \
    echo 'd /var/usrlocal/lib 0755 root root -' >> /usr/lib/tmpfiles.d/ostree-0-integration.conf && \
    echo 'd /var/usrlocal/man 0755 root root -' >> /usr/lib/tmpfiles.d/ostree-0-integration.conf && \
    echo 'd /var/usrlocal/sbin 0755 root root -' >> /usr/lib/tmpfiles.d/ostree-0-integration.conf && \
    echo 'd /var/usrlocal/share 0755 root root -' >> /usr/lib/tmpfiles.d/ostree-0-integration.conf && \
    echo 'd /var/usrlocal/src 0755 root root -' >> /usr/lib/tmpfiles.d/ostree-0-integration.conf && \
    echo 'd /run/media 0755 root root -' >> /usr/lib/tmpfiles.d/ostree-0-integration.conf && \
    mv /var/lib/pacman /usr/lib/ && \
    sed -i -e 's|^#\(DBPath\s*=\s*\).*|\1/usr/lib/pacman|g' -e 's|^#\(IgnoreGroup\s*=\s*\).*|\1modified|g' /usr/etc/pacman.conf && \
    mkdir /usr/lib/pacmanlocal && \
    rm -r /var/*
