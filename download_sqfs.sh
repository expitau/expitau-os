#!/bin/bash
set -euxo pipefail

mkdir -p chunks
curl -s https://api.github.com/repos/expitau/expitau-os/releases/latest | grep -oP '"browser_download_url": "\K[^"]*chunk-[^"]*' | xargs -n 1 wget -c -P chunks
cat chunks/* > arch.sqfs
