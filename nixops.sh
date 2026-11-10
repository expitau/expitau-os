#!/usr/bin/env bash
# nixops.sh - Scripts for NixOS configuration

set -euo pipefail

# --- Helper functions ---

usage() {
  cat <<EOF
Usage: $0 <command>

Commands:
  switch            Rebuild and switch to current NixOS configuration
  push <target>     Push the current NixOS configuration to the target system
  update-lockfile   Update the Nix flake lockfile
  fmt | format      Format .nix files
  upgrade | update  Update flake and rebuild system
  clean             Clean Nix store and optimize space
  list              List system profile differences
EOF
}

# --- Commands ---
switch() {
  local host="${1:-$(hostname)}"
  sudo nixos-rebuild switch --flake path:.#"$host"
}

push() {
  local target="$1"
  # Only run if git up to date
  git diff --quiet || { echo "Git repository is not up to date. Please commit or stash changes."; exit 1; }
  git push
  ssh "$target" "cd ~/.nixos && git pull && sudo nixos-rebuild switch --flake path:.#"$target""
}

update_lockfile() {
  sudo nix flake update --flake path:.
  git add flake.lock
  git commit -S -m "$(date +'%Y %b %d') Update"
}

fmt() {
  nixfmt $(find . -iname "*.nix")
}

upgrade() {
  update_lockfile
  switch
}

clean() {
  sudo nix-collect-garbage --delete-older-than 7d
  sudo nix profile wipe-history
  nix store gc
  sudo nix store optimise
  sudo nixos-rebuild boot --flake path:.#$(hostname)
}

list_profiles() {
  nix profile diff-closures --profile /nix/var/nix/profiles/system
}

# --- Main dispatcher ---

case "${1:-}" in
  switch) switch ;;
  push) push "$2" ;;
  update-lockfile) update_lockfile ;;
  fmt|format) fmt ;;
  upgrade|update) upgrade ;;
  clean) clean ;;
  list) list_profiles ;;
  *) usage ;;
esac
