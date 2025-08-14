.PHONY: switch upgrade update fmt format

switch:
	sudo nixos-rebuild switch --flake /etc/nixos#expitau-nixos

upgrade:
	sudo nix flake update

fmt:
	nix fmt

update: upgrade

format: fmt
