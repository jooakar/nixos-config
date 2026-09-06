# Nix configuration

Hosts:

| Host         | Platform       | Built with                            |
| ------------ | -------------- | ------------------------------------- |
| `maxos`      | aarch64-darwin | `make darwin NIXNAME=maxos`           |
| `maxos-work` | aarch64-darwin | `make darwin NIXNAME=maxos-work`      |
| `vps`        | x86_64-linux   | `make nixos` (on the server)          |

The Macs and the server share `modules/packages.nix` and `modules/home-manager`; macOS-only
bits (Homebrew casks, fonts, aerospace/ghostty config, `pbcopy`, OrbStack, the Bitwarden SSH
agent socket) are gated on the `isDarwin` flag passed through `specialArgs`.

## Bootstrapping the VPS

The server is an UpCloud KVM instance. Partitioning is declared with
[disko](https://github.com/nix-community/disko) in `modules/nixos/disko.nix`: GPT with a
`bios_grub` partition, a 512M ESP and an ext4 root, so it boots under either BIOS or UEFI.

The local machine is aarch64 and cannot build x86_64-linux, so everything is built on the
target.

1. Create the server from any Linux template with root SSH key access.
2. Check the disk name on the target with `lsblk`. If it is not `/dev/vda`, change
   `diskDevice` in `flake.nix` first.
3. From the Mac:

   ```sh
   make bootstrap HOST=<ip>
   ```

   `nixos-anywhere` kexecs into the NixOS installer, runs disko, then installs.
   `--build-on remote` keeps every build off the aarch64 host; nearly the whole closure comes
   from `cache.nixos.org`, so this is mostly downloading.
4. After it reboots: `ssh joona@<ip>` then `sudo tailscale up`.
5. Afterwards, clone this repo on the server and use `make nixos`, or let
   `system.autoUpgrade` pull from GitHub weekly.

If `nixos-anywhere` cannot kexec, boot UpCloud's rescue environment and run
`nix run github:nix-community/disko -- --mode disko --flake .#vps` followed by
`nixos-install --flake .#vps` by hand.

**Note:** running disko is destructive. It is only for the initial install, never on a
provisioned box.
