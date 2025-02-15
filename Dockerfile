FROM archlinux:base-devel

RUN pacman -Syu --noconfirm
RUN pacman -S reflector --noconfirm
RUN reflector --latest 5 --country CA --country US --sort rate --save /etc/pacman.d/mirrorlist
RUN pacman -S arch-install-scripts squashfs-tools reflector cargo rustup git --noconfirm
RUN rustup default stable

RUN git clone https://aur.archlinux.org/paru-bin.git /paru && chown -R nobody:nobody /paru && cd /paru && sudo -u nobody makepkg --noconfirm

RUN echo "root:0:1000" >> /etc/subuid && echo "root:0:1000" >> /etc/subgid
COPY scripts /scripts

COPY system/Cargo.toml system/Cargo.lock /src/
COPY system/src /src/src
RUN cd /src && cargo build --release

CMD [ "bash", "scripts/build.sh" ] 
