#!/bin/bash

# Check if /var/home doesn't exist or is empty
if [ ! -d "/var/home" ] || [ -z "$(ls -A /var/home)" ]; then
  echo "/var/home doesn't exist or is empty. Copying /usr/homesetup to /var/home..."
  mkdir -p /var/home
  cp -rp /usr/homesetup/* /var/home
  echo "Copy complete."
else
  echo "/var/home exists and is not empty. No files were copied."
fi
