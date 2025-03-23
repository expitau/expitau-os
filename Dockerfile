ARG SYSTEM_USER=user
ARG SYSTEM_PW=JHkkajlUJFI3V3dTdVYxbEsxTWdhWlFlVjBsbzAkTkMyaTNjd2ovZnVvZE84UXN4NlptblFWaWhFeE1sa0xjV0dWcmw3UGRyNgo=

# Build image, this is the "ISO" that will be used to create the chroot environment
FROM archlinux:base-devel as iso
ARG SYSTEM_USER SYSTEM_PW

# Copy host's pacman cache if not initialized
RUN --mount=type=cache,from=cache,target=/var/cache/pacman/pkg echo "Cache has $(du -sh /var/cache/pacman/pkg | awk '{print $1}')"

RUN --mount=type=cache,from=cache,target=/var/cache/pacman/pkg pacman -Syu --noconfirm

RUN --mount=type=cache,from=cache,target=/var/cache/pacman/pkg pacman -S arch-install-scripts rust git --noconfirm

RUN echo "root:0:1000" >> /etc/subuid && echo "root:0:1000" >> /etc/subgid

COPY system /src/system
RUN cd /src/system && cargo build --release

COPY scripts /scripts

RUN --mount=type=cache,from=cache,target=/var/cache/pacman/pkg SYSTEM_USER=$SYSTEM_USER SYSTEM_PW=$SYSTEM_PW bash scripts/build.sh

# Our main system. Everything is installed here.
FROM scratch as chroot
ARG SYSTEM_USER SYSTEM_PW
COPY --from=iso /mnt /

RUN --mount=type=cache,from=cache,target=/var/cache/pacman/pkg SYSTEM_USER=$SYSTEM_USER SYSTEM_PW=$SYSTEM_PW bash /setup.sh

RUN rm /setup.sh

# Cleanup and create the final image
FROM archlinux:base-devel as image
COPY --from=chroot / /mnt

RUN --mount=type=cache,from=cache,target=/var/cache/pacman/pkg pacman -Sy squashfs-tools --noconfirm

RUN mksquashfs /mnt /arch.sqfs
