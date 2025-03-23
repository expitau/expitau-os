ARG SYSTEM_USER=user
ARG SYSTEM_PW=JHkkajlUJFI3V3dTdVYxbEsxTWdhWlFlVjBsbzAkTkMyaTNjd2ovZnVvZE84UXN4NlptblFWaWhFeE1sa0xjV0dWcmw3UGRyNgo=

FROM archlinux:base-devel as iso

# Copy host's pacman cache if not initialized
RUN --mount=type=bind,source=./cache,target=/tmp/cache ls /tmp/cache
# RUN --mount=type=bind,source=./cache,target=/tmp/cache \
#     --mount=type=cache,target=/var/cache/pacman/pkg \
#     [ "\$(ls -A /var/cache/pacman/pkg)" ] \
#         && echo "Cache already exists: $(du -sh /var/cache/pacman/pkg | awk '{print $1}')" \
#         || (echo "Cache is empty. Populating from host's ./cache." && cp -r /tmp/cache/* /var/cache/pacman/pkg || true)

RUN pacman -Syu --noconfirm

RUN pacman -S arch-install-scripts rust git --noconfirm

RUN echo "root:0:1000" >> /etc/subuid && echo "root:0:1000" >> /etc/subgid

COPY system /src/system
RUN cd /src/system && cargo build --release

COPY scripts /scripts

RUN --mount=type=cache,target=/var/cache/pacman/pkg SYSTEM_USER=${SYSTEM_USER} SYSTEM_PW=${SYSTEM_PW} bash scripts/build.sh

# FROM scratch as chroot

# COPY --from=iso /mnt /

# RUN --mount=type=cache,target=/var/cache/pacman/pkg SYSTEM_USER=${SYSTEM_USER} SYSTEM_PW=${SYSTEM_PW} bash /setup.sh

# RUN rm /setup.sh

# FROM archlinux:base-devel as image

# COPY --from=chroot / /mnt

# RUN pacman -S squashfs-tools --noconfirm

# RUN mksquashfs /mnt /arch.sqfs
