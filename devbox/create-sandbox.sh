#!/usr/bin/env bash
CONTAINER_NAME=formic-sandbox
CONTAINER_IMAGE=images:archlinux/cloud

# Delete existing LXD container if it exists
incus delete $CONTAINER_NAME -f || true

# Create new LXD container with devbox configuration
echo "Initializing container..."
incus init $CONTAINER_IMAGE $CONTAINER_NAME \
    -c user.user-data="$(cat $CONTAINER_NAME.yaml)" \
    -c limits.memory=24GB \
    -c limits.processes=4000 \
    -c limits.memory.swap=false \
    -c security.nesting=true
    # -c limits.cpu=10 \
# Mount disks
echo "Mounting disks..."

incus config device override formic-sandbox root size=100GiB

mkdir -p /home/nathan/.devbox/$CONTAINER_NAME
incus config device add $CONTAINER_NAME $CONTAINER_NAME-home disk \
    source=/home/nathan/.devbox/$CONTAINER_NAME \
    path="/home/nathan"

# incus config device add $CONTAINER_NAME $CONTAINER_NAME-project disk \
#     source=/home/nathan/Data/Projects/Rust/Experiment/foil-fs \
#     path="/home/nathan/foil-fs" \
#     shift=true # Map uid mappings from host 1000 to container for permissions

# Configuration
echo "Starting container..."
incus start $CONTAINER_NAME

# Wait for the container to be ready
incus exec "$CONTAINER_NAME" -- tail -n +1 -F /var/log/cloud-init-output.log &
TAIL_PID=$!
trap 'kill "$TAIL_PID" 2>/dev/null' EXIT

incus exec "$CONTAINER_NAME" -- cloud-init status --wait --long > /dev/null
