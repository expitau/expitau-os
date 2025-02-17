#!/bin/bash
set -e

podman build -t archbuild .
# The environment variables are set in the host
podman run --cap-add SYS_ADMIN --security-opt unmask=/proc/* --security-opt label=disable -v ./cache:/var/cache/pacman/pkg --env USER=$USER --env PW=$PW --name archbuild --replace archbuild
podman cp archbuild:/arch.sqfs .
podman rm archbuild
