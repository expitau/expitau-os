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

clean:
	sudo nix-collect-garbage --delete-older-than 7d
	sudo nix profile wipe-history
	nix store gc
	sudo nix store optimise
	sudo nixos-rebuild boot

list:
	nix profile diff-closures --profile /nix/var/nix/profiles/system
