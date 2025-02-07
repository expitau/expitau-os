FROM archlinux:base-devel

RUN pacman -Syu --noconfirm
RUN pacman -S arch-install-scripts squashfs-tools reflector --noconfirm
RUN reflector --latest 5 --country CA --country US --sort rate --save /etc/pacman.d/mirrorlist

RUN echo "root:0:1000" >> /etc/subuid && echo "root:0:1000" >> /etc/subgid
COPY scripts /scripts
COPY system/target/release/system /scripts/system

CMD [ "bash", "scripts/build.sh" ] 
