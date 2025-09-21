.PHONY: switch update-lockfile upgrade update fmt format

switch:
	NEXT_GENERATION=$(($(nix-env --list-generations | grep current | awk '{print $1}')+1)) && \
	git add . && \
	git commit -S -m "Switch to generation $$NEXT_GENERATION" && \
	git push && \
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
