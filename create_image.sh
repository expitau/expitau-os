podman build -t archbuild .
podman run --security-opt unmask=/proc/* --security-opt label=disable -v ./cache:/var/cache/pacman/pkg --name archbuild --replace archbuild
podman cp archbuild:/arch.sqfs .
