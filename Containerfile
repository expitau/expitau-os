FROM docker.io/alpine:3.19 AS downloader

###
# Your code
###
RUN apk add --no-cache coreutils sequoia-sq tar wget zstd

WORKDIR /tmp

RUN wget http://mirror.cmt.de/archlinux/iso/latest/b2sums.txt
RUN wget http://mirror.cmt.de/archlinux/iso/latest/sha256sums.txt
RUN wget http://mirror.cmt.de/archlinux/iso/latest/archlinux-bootstrap-x86_64.tar.zst
RUN wget http://mirror.cmt.de/archlinux/iso/latest/archlinux-bootstrap-x86_64.tar.zst.sig
RUN sq --force wkd get pierre@archlinux.org -o release-key.pgp

RUN b2sum --ignore-missing -c b2sums.txt
RUN sha256sum --ignore-missing -c sha256sums.txt
RUN sq verify --signer-file release-key.pgp --detached archlinux-bootstrap-x86_64.tar.zst.sig archlinux-bootstrap-x86_64.tar.zst

WORKDIR /

RUN mkdir /rootfs
RUN tar xf /tmp/archlinux-bootstrap-x86_64.tar.zst --numeric-owner -C /rootfs

FROM scratch AS live
COPY --from=downloader /rootfs/root.x86_64 /

RUN pacman-key --init
RUN pacman-key --populate
RUN echo 'Server = https://geo.mirror.pkgbuild.com/$repo/os/$arch' > /etc/pacman.d/mirrorlist

###
# My code
###

RUN install -d /mnt/etc
RUN echo "HOOKS=(base systemd ostree autodetect modconf kms keyboard keymap consolefont block btrfs filesystems fsck)" > /mnt/etc/mkinitcpio.conf

RUN pacman --noconfirm -Syyu
RUN pacman --noconfirm -S ostree

RUN ostree admin init-fs --sysroot /mnt --modern /mnt && \
	ostree admin stateroot-init --sysroot /mnt archlinux && \
	ostree config --repo /mnt/ostree/repo set sysroot.bootprefix 1

RUN pacstrap -c -G -M /mnt base linux linux-headers linux-firmware grub mkinitcpio podman ostree which

FROM scratch AS final
COPY --from=live /mnt /

RUN mkdir /efi

# Normal post installation steps.
RUN ln -sf /usr/share/zoneinfo/UTC /etc/localtime
RUN sed -i 's/^#\(en_US.UTF-8 UTF-8\)/\1/' /etc/locale.gen
RUN locale-gen
RUN systemctl enable systemd-timesyncd.service

RUN echo 'My specific container setup' > /myfile

# Prepre OSTree integration (https://wiki.archlinux.org/title/Mkinitcpio#Common_hooks)
RUN mkdir -p /etc/mkinitcpio.conf.d \
 && echo "HOOKS=(base systemd ostree autodetect modconf kms keyboard sd-vconsole block filesystems fsck)" > /etc/mkinitcpio.conf.d/ostree.conf

# OSTree: Prepare microcode and initramfs
RUN moduledir=$(find /usr/lib/modules -mindepth 1 -maxdepth 1 -type d) && \
    cat /boot/initramfs-linux-fallback.img > ${moduledir}/initramfs.img

# OSTree: Bootloader integration
RUN cp /usr/lib/libostree/* /etc/grub.d && \
	chmod +x /etc/grub.d/15_ostree

RUN RUN echo "root:ostree" | chpasswd

FROM scratch AS ostreeify

COPY --from=downloader /rootfs/root.x86_64 /
COPY --from=final / /mnt

RUN pacman-key --init
RUN pacman-key --populate
RUN echo 'Server = https://geo.mirror.pkgbuild.com/$repo/os/$arch' > /etc/pacman.d/mirrorlist

RUN pacman --noconfirm -Syyu
RUN pacman --noconfirm -S ostree

# Now create ostree repo and commit /mnt to it 

RUN mv /mnt/etc /mnt/usr/ && \
    rm -r /mnt/home && \
    ln -s var/home /mnt/home && \
    rm -r /mnt/mnt && \
    ln -s var/mnt /mnt/mnt && \
    rm -r /mnt/opt && \
    ln -s var/opt /mnt/opt && \
    rm -r /mnt/root && \
    ln -s var/roothome /mnt/root && \
    rm -r /mnt/srv && \
    ln -s var/srv /mnt/srv && \
    mkdir /mnt/sysroot && \
    ln -s sysroot/ostree /mnt/ostree && \
    rm -r /mnt/usr/local && \
    ln -s ../var/usrlocal /mnt/usr/local && \
    echo 'd /var/home 0755 root root -' >> /mnt/usr/lib/tmpfiles.d/ostree-0-integration.conf && \
    echo 'd /var/lib 0755 root root -' >> /mnt/usr/lib/tmpfiles.d/ostree-0-integration.conf && \
    echo 'd /var/log/journal 0755 root root -' >> /mnt/usr/lib/tmpfiles.d/ostree-0-integration.conf && \
    echo 'd /var/mnt 0755 root root -' >> /mnt/usr/lib/tmpfiles.d/ostree-0-integration.conf && \
    echo 'd /var/opt 0755 root root -' >> /mnt/usr/lib/tmpfiles.d/ostree-0-integration.conf && \
    echo 'd /var/roothome 0700 root root -' >> /mnt/usr/lib/tmpfiles.d/ostree-0-integration.conf && \
    echo 'd /var/srv 0755 root root -' >> /mnt/usr/lib/tmpfiles.d/ostree-0-integration.conf && \
    echo 'd /var/usrlocal 0755 root root -' >> /mnt/usr/lib/tmpfiles.d/ostree-0-integration.conf && \
    echo 'd /var/usrlocal/bin 0755 root root -' >> /mnt/usr/lib/tmpfiles.d/ostree-0-integration.conf && \
    echo 'd /var/usrlocal/etc 0755 root root -' >> /mnt/usr/lib/tmpfiles.d/ostree-0-integration.conf && \
    echo 'd /var/usrlocal/games 0755 root root -' >> /mnt/usr/lib/tmpfiles.d/ostree-0-integration.conf && \
    echo 'd /var/usrlocal/include 0755 root root -' >> /mnt/usr/lib/tmpfiles.d/ostree-0-integration.conf && \
    echo 'd /var/usrlocal/lib 0755 root root -' >> /mnt/usr/lib/tmpfiles.d/ostree-0-integration.conf && \
    echo 'd /var/usrlocal/man 0755 root root -' >> /mnt/usr/lib/tmpfiles.d/ostree-0-integration.conf && \
    echo 'd /var/usrlocal/sbin 0755 root root -' >> /mnt/usr/lib/tmpfiles.d/ostree-0-integration.conf && \
    echo 'd /var/usrlocal/share 0755 root root -' >> /mnt/usr/lib/tmpfiles.d/ostree-0-integration.conf && \
    echo 'd /var/usrlocal/src 0755 root root -' >> /mnt/usr/lib/tmpfiles.d/ostree-0-integration.conf && \
    echo 'd /run/media 0755 root root -' >> /mnt/usr/lib/tmpfiles.d/ostree-0-integration.conf && \
    mv /mnt/var/lib/pacman /mnt/usr/lib/ && \
    sed -i \
        -e 's|^#\(DBPath\s*=\s*\).*|\1/usr/lib/pacman|g' \
        -e 's|^#\(IgnoreGroup\s*=\s*\).*|\1modified|g' \
        /mnt/usr/etc/pacman.conf && \
    mkdir /mnt/usr/lib/pacmanlocal && \
    rm -r /mnt/var/*

FROM scratch as export

COPY --from=ostreeify /mnt /

# ENTRYPOINT ostree commit --repo /sysroot/ostree/repo --tree=dir=/mnt --branch=archlinux
