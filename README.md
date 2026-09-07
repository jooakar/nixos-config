# Nix configuration

Hosts:

| Host         | Platform       | Built with                            |
| ------------ | -------------- | ------------------------------------- |
| `maxos`      | aarch64-darwin | `make darwin NIXNAME=maxos`           |
| `maxos-work` | aarch64-darwin | `make darwin NIXNAME=maxos-work`      |
| `vps`        | x86_64-linux   | `make nixos` (on the server)          |

Darwin and servers share `modules/packages.nix` and `modules/home-manager`. Darwin-only
bits are gated on the `isDarwin` flag passed through `specialArgs`.

## Layout

```
config/       dotfiles copied into place by home-manager
modules/      the machine configs: darwin, nixos, home-manager
secrets/      agenix-encrypted credentials, one rules file
terraform/    the UpCloud server, its firewall, and the installer CD
cluster/      GitOps. Argo CD's root Application tracks cluster/<hostname>
scripts/tf.sh decrypts credentials, then execs terraform
```

## Deploys

Terraform provisions the machine; it does not deploy config. Use `make nixos` on the server,
or remotely:

```sh
nix run nixpkgs#nixos-rebuild -- switch --flake 'path:.#vps' \
  --target-host root@<ip> --build-host root@<ip>
```

`system.autoUpgrade` is also enabled and pulls `github:jooakar/nixos-config` weekly, so
anything pushed to `main` reaches the server on its own.

## k3s and Argo CD

`modules/nixos/k3s.nix` runs a single-node k3s server. Traefik is disabled and ingress is
cluster content which comes from `cluster/`.

The initial admin password:

```sh
kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath='{.data.password}' | base64 -d
```

`kubectl` works as `joona` without sudo: k3s writes its kubeconfig group-readable to the
`k3s` group, and `KUBECONFIG` is set system-wide.

The API server is not exposed publicly. Port 6443 is only reachable over `tailscale0`, which
is a trusted interface. Add your tailnet MagicDNS name to `--tls-san` in
`modules/nixos/k3s.nix` before using `kubectl` from another machine, or the certificate will
not match.

## Prerequisites

`nix develop` gives you terraform, agenix, kubectl, helm, argocd and k9s.

### Secrets

Secrets are [agenix](https://github.com/ryantm/agenix) files under `secrets/`, 
encrypted to the SSH key listed in `secrets/secrets.nix`.

## PostgreSQL

Postgres runs on the host, not in the cluster, so nothing in k3s holds state that cannot be
dropped and rebuilt from git. It listens on every interface, because the cni0 gateway address
does not exist until k3s has started; the firewalls are the only thing keeping 5432 off the
public interface.

### Per-service databases

`modules/nixos/databases.nix` is a list of names. Each one gets a database, a role of the
same name that owns it, and a password from `secrets/pg-<name>.age`. Each service only
has access to its own database.

### Backups

`services.postgresqlBackup` dumps every database to `/var/backup/postgresql` at 03:00 daily.
That directory is on the root disk, so it survives a k3s wipe but not a Terraform destroy;
ship it off-box with the `rclone` that is already in the package set.

## Provisioning

In UpCloud, `kexec` does not work so a NixOS installer CD is used to boostrap
NixOS instead.

1. Boot the installer:

   ```sh
   ./scripts/tf.sh apply -var bootstrap=true
   ```

   This creates the server if needed, attaches the NixOS CD and sets
   `boot_order = "cdrom,disk"`.

2. Open the server's console in <https://hub.upcloud.com>. The installer
   auto-logs in as `nixos` with passwordless sudo, so there is nothing to enter.
   Give root a password so the install can connect:

   ```sh
   sudo passwd root
   ```

   If `/` types as something else, run `loadkeys us`. The browser console has
   already applied your local layout; loading a second one translates twice.

3. Install, from the repo root:

   ```sh
   export SSHPASS=<the password from step 2>
   ./scripts/tf.sh output -raw install_command
   ```

4. Boot the system you just installed:

   ```sh
   ./scripts/tf.sh apply
   ```

   `bootstrap` defaults to false, so this detaches the CD and sets
   `boot_order = "disk"`. Flipping it stops and starts the server.

5. `ssh <user>@<ip>`, then `sudo tailscale up`.
