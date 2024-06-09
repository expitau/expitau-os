FROM archlinux

RUN pacman -Syu --noconfirm
RUN pacman -S ostree --noconfirm

ENTRYPOINT 
