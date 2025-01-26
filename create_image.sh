podman build -t archbuild .
podman run --privileged --name archbuild archbuild
podman cp archbuild:/arch.sqfs .

