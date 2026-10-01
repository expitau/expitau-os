#!/usr/bin/env bash
CONTAINER_NAME=formic-work
CONTAINER_IMAGE=images:ubuntu/jammy/cloud

# Delete existing LXD container if it exists
incus delete $CONTAINER_NAME -f || true

# Create new LXD container with devbox configuration
echo "Initializing container..."
incus init $CONTAINER_IMAGE $CONTAINER_NAME \
    -c user.user-data="$(cat $CONTAINER_NAME.yaml)" \
    -c limits.memory=16GB \
    -c limits.cpu.allowance=50% \
    -c security.nesting=true

# Mount disks
echo "Mounting disks..."
incus config device add $CONTAINER_NAME $CONTAINER_NAME-data disk \
    source=/home/nathan/Data \
    path="/mnt/data" \
    shift=true # Map uid mappings from host 1000 to container for permissions

mkdir -p /home/nathan/.devbox/$CONTAINER_NAME
incus config device add $CONTAINER_NAME $CONTAINER_NAME-home disk \
    source=/home/nathan/.devbox/$CONTAINER_NAME \
    path="/home/nathan" \
    shift=true # Map uid mappings from host 1000 to container for permissions

# Configuration
echo "Starting container..."
incus start $CONTAINER_NAME

# Wait for the container to be ready
incus exec "$CONTAINER_NAME" -- tail -n +1 -F /var/log/cloud-init-output.log &
TAIL_PID=$!
trap 'kill "$TAIL_PID" 2>/dev/null' EXIT

incus exec "$CONTAINER_NAME" -- cloud-init status --wait --long > /dev/null
