.PHONY: switch update-lockfile upgrade update fmt format

switch:
	sudo nixos-rebuild switch --flake /etc/nixos#expitau-nixos

update-lockfile:
	sudo nix flake update

fmt:
	nixfmt *.nix

upgrade: update-lockfile switch

update: upgrade

format: fmt
