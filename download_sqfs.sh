#!/bin/bash

mkdir -p chunks
curl -s https://api.github.com/repos/expitau/System/releases/latest | grep -oP '"browser_download_url": "\K[^"]*chunk-[^"]*' | xargs -n 1 wget -c -P chunks
cat chunks/* > arch2.sqfs
