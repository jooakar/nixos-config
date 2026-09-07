NIXFLAGS := --extra-experimental-features nix-command --extra-experimental-features flakes

# macOS. Run on the Mac: make darwin NIXNAME=maxos
darwin:
	nix build $(NIXFLAGS) ".#darwinConfigurations.${NIXNAME}.system"
	sudo ./result/sw/bin/darwin-rebuild switch --flake ".#${NIXNAME}"

build: darwin

# NixOS. Run on the server itself.
nixos:
	sudo nixos-rebuild switch --flake ".#vps"

# When first setting up the UpCloud VPS, this boots from a NixOS CD
# Other steps in README
bootstrap:
	./scripts/tf.sh apply -var bootstrap=true

.PHONY: darwin build nixos bootstrap
