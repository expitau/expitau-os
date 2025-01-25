FROM archlinux:base-devel

RUN pacman -Syu --noconfirm
RUN pacman -S arch-install-scripts squashfs-tools --noconfirm

RUN echo "root:0:1000" >> /etc/subuid && echo "root:0:1000" >> /etc/subgid
COPY scripts ./scripts
CMD [ "bash", "scripts/build.sh" ] 
