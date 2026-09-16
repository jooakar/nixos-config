NIXFLAGS := --extra-experimental-features nix-command --extra-experimental-features flakes
HASH := \#

# macOS. Run on the Mac: make darwin HOST=maxos
darwin:
	nix build $(NIXFLAGS) ".#darwinConfigurations.${HOST}.system"
	sudo ./result/sw/bin/darwin-rebuild switch --flake ".#${HOST}"

build: darwin

# NixOS. Build remotely: make nixos HOST=vps
remote:
	nix run nixpkgs$(HASH)nixos-rebuild -- switch --flake ".#${HOST}" --target-host root@${HOST}.ts.joona.codes --build-host root@${HOST}.ts.joona.codes

# When first setting up the UpCloud VPS, this boots from a NixOS CD
# Other steps in README
bootstrap:
	./scripts/tf.sh apply -var bootstrap=true

.PHONY: darwin build remote bootstrap
