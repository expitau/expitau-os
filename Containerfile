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
RUN echo "HOOKS=(base systemd ostree autodetect modconf kms keyboard keymap consolefont block filesystems fsck)" > /mnt/etc/mkinitcpio.conf

RUN pacman --noconfirm -Syyu
RUN pacman --noconfirm -S ostree

RUN ostree admin init-fs --sysroot /mnt --modern /mnt && \
	ostree admin stateroot-init --sysroot /mnt archlinux && \
	ostree config --repo /mnt/ostree/repo set sysroot.bootprefix 1

RUN pacstrap -c -G -M /mnt base linux linux-firmware grub ostree

FROM scratch AS final
COPY --from=live /mnt /

RUN mkdir /efi

# Normal post installation steps.
RUN ln -sf /usr/share/zoneinfo/UTC /etc/localtime
RUN sed -i 's/^#\(en_US.UTF-8 UTF-8\)/\1/' /etc/locale.gen
RUN locale-gen
RUN systemctl enable systemd-timesyncd.service

RUN echo 'My specific container setup' > /myfile

FROM scratch AS export

COPY --from=downloader /rootfs/root.x86_64 /
COPY --from=final / /mnt

RUN pacman-key --init
RUN pacman-key --populate
RUN echo 'Server = https://geo.mirror.pkgbuild.com/$repo/os/$arch' > /etc/pacman.d/mirrorlist

RUN pacman --noconfirm -Syyu
RUN pacman --noconfirm -S ostree

# Now create ostree repo and commit /mnt to it 
RUN mv "/mnt/home" "/mnt/var/" && \
	ln -s var/home "/mnt/home" && \
	mv "/mnt/mnt" "/mnt/var/" && \
	ln -s var/mnt "/mnt/mnt" && \
	mv "/mnt/root" "/mnt/var/roothome" && \
	ln -s var/roothome "/mnt/root" && \
	rm -r "/mnt/usr/local" && \
	ln -s ../var/usrlocal "/mnt/usr/local" && \
	mv "/mnt/srv" "/mnt/var/srv" && \
	ln -s var/srv "/mnt/srv" && \
	mkdir "/mnt/sysroot" && \
	ln -s sysroot/ostree "/mnt/ostree" && \
	mv "/mnt/etc" "/mnt/usr/" && \
	rm -r "/mnt/boot" && \
	mkdir "/mnt/boot"

ENTRYPOINT ostree commit --repo /sysroot/ostree/repo --tree=dir=/mnt --branch=archlinux
