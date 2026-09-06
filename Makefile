NIXFLAGS := --extra-experimental-features nix-command --extra-experimental-features flakes

# macOS. Run on the Mac: make darwin NIXNAME=maxos
darwin:
	nix build $(NIXFLAGS) ".#darwinConfigurations.${NIXNAME}.system"
	sudo ./result/sw/bin/darwin-rebuild switch --flake ".#${NIXNAME}"

build: darwin

# NixOS. Run on the server itself; aarch64 Macs cannot build x86_64-linux.
nixos:
	sudo nixos-rebuild switch --flake ".#vps"

# First install, run from the Mac against a fresh UpCloud server. See README.md.
bootstrap:
	nix run $(NIXFLAGS) github:nix-community/nixos-anywhere -- \
		--flake ".#vps" --build-on remote root@$(HOST)

.PHONY: darwin build nixos bootstrap
