cd ~/System && \
git pull && sudo podman build --file ~/System/Containerfile --cap-add=SYS_ADMIN --security-opt label=disable --tag archlinux/latest && \
sudo mkdir /var/home/fedora/rootfs && \
sudo podman export $(sudo podman create archlinux/latest bash) > /var/home/fedora/rootfs.tar && sudo tar -xf /var/home/fedora/rootfs.tar -C /var/home/fedora/rootfs && \
sudo ostree commit --branch=archlinux/latest --tree=dir=/var/home/fedora/rootfs && \
sudo ostree admin deploy --no-merge --karg="root=LABEL=fedora_fedora rootflags=subvol=root rw" --retain archlinux/latest
