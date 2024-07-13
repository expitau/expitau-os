#!/bin/bash

# Check if /var is empty
if [ -z "$(ls -A /var)" ]; then
  echo "/var is empty. Copying /usr/varsetup to /var..."
  cp -r /usr/varsetup/* /var
  echo "Copy complete."
else
  echo "/var is not empty. No files were copied."
fi
