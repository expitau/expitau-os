cd ~/System && \
git pull && podman build --file ~/System/Containerfile --no-hosts --no-hostname --dns=none --cap-add=SYS_ADMIN --security-opt label=disable --tag archlinux/latest && \
mkdir /var/rootfs && \
podman export $(podman create archlinux/latest bash) > /var/rootfs.tar && tar -xf /var/rootfs.tar -C /var/rootfs && \
ostree commit --branch=archlinux/latest --tree=dir=/var/rootfs && \
ostree admin deploy --no-merge --karg="root=LABEL=fedora_fedora rootflags=subvol=root rw" --retain archlinux/latest
