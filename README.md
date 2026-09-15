# Nix configuration

Hosts:

| Host     | Platform       | What it is               | Built with                   |
| -------- | -------------- | ------------------------ | ---------------------------- |
| `maxos`  | aarch64-darwin | personal laptop          | `make darwin NIXNAME=maxos`  |
| `work`   | aarch64-darwin | work laptop              | `make darwin NIXNAME=work`   |
| `vps`    | x86_64-linux   | UpCloud server           | `make nixos NIXNAME=vps`     |
| `carbon` | x86_64-linux   | X1 Carbon gen 5, at home | `make nixos NIXNAME=carbon`  |

Every host is one file in `hosts/`, named after the flake attribute, and `mkDarwin` /
`mkNixos` in `flake.nix` take that file as their only module. Darwin-only bits inside the
shared modules are gated on the `isDarwin` flag passed through `specialArgs`.

## Layout

```
hosts/<name>.nix     the only place that picks modules for a machine
config/              dotfiles copied into place by home-manager
modules/packages/    common, workstation and server package sets, imported per host
modules/nixos/base.nix        everything every NixOS host gets
modules/nixos/hardware/       one file per machine's hardware and bootloader
modules/nixos/disko/          one file per machine's disk layout
modules/nixos/services/       one file per service, imported by the hosts that run it
modules/nixos/apps/           one file per application running on the server
secrets/             agenix-encrypted env files, one rules file
terraform/           the UpCloud server, its firewall, and the DNS records
scripts/tf.sh        decrypts credentials, then execs terraform
```

## Deploys

Run `make <nixos|darwin> NIXNAME=<host>`, or remotely:

```sh
nix run nixpkgs#nixos-rebuild -- switch --flake 'path:.#<host>' \
  --target-host root@<ip> --build-host root@<ip>
```

`system.autoUpgrade` is also enabled and pulls this repo weekly

## What runs on the server

Everything is a NixOS service. There is no container orchestrator; `nixos-rebuild` is the
only thing that changes the machine.

| Module                       | What it runs                                             |
| ---------------------------- | -------------------------------------------------------- |
| `services/web.nix`           | nginx and ACME. Every cert is issued over DNS-01.        |
| `services/headscale.nix`     | Headscale, the tailnet's coordination server and relay   |
| `services/adguard.nix`       | AdGuard Home, the tailnet's resolver                     |
| `services/postgres.nix`      | PostgreSQL, one database per application                 |
| `services/monitoring.nix`    | Prometheus, the postgres exporter, Loki, Alloy, Grafana  |
| `services/node-exporter.nix` | the node exporter. `carbon` runs this one too.           |
| `apps/*.nix`                 | one podman container per application                     |
| `services/deploy.nix`        | the restricted SSH identity CI deploys with              |
| `services/restic.nix`        | `mkBackup`, and the R2 credential. `carbon` runs it too  |

`carbon` runs `services/web.nix` too, plus the media stack:

| Module                     | What it runs                                               |
| -------------------------- | ---------------------------------------------------------- |
| `services/nixarr.nix`      | the whole nixarr stack, the VPN namespace, and every vhost |
| `services/jellyfin.nix`    | the QuickSync half, which nixarr has no options for        |
| `services/qbittorrent.nix` | the Proton port forward, which nixarr does not do          |

## The tailnet

Nodes join with a pre-auth key. Setup:

```sh
sudo headscale users create <user>
sudo headscale preauthkeys create --user <user ID> --expiration 24h
```

then on the node, `tailscale up --login-server https://head.joona.codes --auth-key <key>`

## Monitoring

Grafana running on `https://grafana.joona.codes`, tailnet only.

Prometheus and Loki are provisioned as datasources. Alloy tails the systemd journal and 
writes it to Loki. Podman logs container output to the journal, so application logs end
up there too. Dashboards live in `config/grafana/dashboards`

## Applications

One file per application under `modules/nixos/apps/`. It declares the container, its
nginx vhost, and the systemd ordering. The image tag is mutable and CI restarts the unit
after pushing to it.

Adding an app:
1. Give it a database in `modules/nixos/services/databases.nix`
2. Give it an env file in `secrets/host/<app>.age`
3. Give it a module in `modules/nixos/apps/<app>.nix`
4. Import it in `hosts/<host>.nix`.

### The deploy credential

CI restarts podman containers over SSH on the tailnet. `modules/nixos/deploy.nix` holds a
`deploy` user whose key is pinned to a forced command, so the key cannot do anything else.

## Prerequisites

`nix develop` gives you terraform, agenix, age and the UpCloud CLI.

### Secrets

Secrets are [agenix](https://github.com/ryantm/agenix) files under `secrets/`, one per
service or goal, each a list of `KEY=VALUE` lines:

```
secrets/env/<goal>.age      workstation only, sourced by scripts/tf.sh
secrets/host/<service>.age  workstation and the host(s) that run the service
```

`secrets.nix` lists recipients per host

## PostgreSQL

### Per-service databases

`modules/nixos/databases.nix` is a list of names. Each one gets a database, a role of the
same name that owns it, and a password from `DB_PASSWORD` in `secrets/host/<name>.age`.
Each service only has access to its own database.

### Backups

`services.postgresqlBackup` dumps every database to `/var/backup/postgresql` at 03:00 daily.
That directory is on the root disk, so it survives a rebuild. `services/restic.nix` then
ships those dumps offsite; see below.

## Backups

`services/restic.nix` exposes `mkBackup`, and services declare what they want kept.

```nix
services.restic.backups.<name> = mkBackup { paths = [ ... ]; exclude = [ ... ]; };
```

Everything lands in one Cloudflare R2 bucket, one repository per host, daily at 04:00 with
a 30 minute spread, keeping 7 daily, 5 weekly and 12 monthly snapshots. Repositories
initialise themselves, so a new host needs nothing done to the bucket by hand.

| Host     | What                        | Why                                              |
| -------- | --------------------------- | ------------------------------------------------ |
| `vps`    | `/var/backup/postgresql`    | the dumps, which are consistent; not the cluster |
| `carbon` | `/data/.state/nixarr`       | every arr's config, ABS progress, qBittorrent's resume data |

### Restoring

```sh
sudo restic-nixarr snapshots            # the wrapper the module installs, per backup
sudo restic-nixarr restore latest --target /tmp/restore
```

The wrapper carries the repository and credentials, so no flags are needed.

## Provisioning a VPS

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

5. `ssh <user>@<ip>`, then join the tailnet with a key from `headscale preauthkeys create`:

   ```sh
   sudo tailscale up --login-server https://head.joona.codes --auth-key <key>
   ```

   `sudo headscale nodes list` then gives the address that `var.tailscale_ip` has to hold.

## Getting a new NixOS host up

1. Clone this repo onto a NixOS bootable installer, then partition, format and mount:

   ```sh
   sudo nix --experimental-features 'nix-command flakes' run github:nix-community/disko -- \
     --mode destroy,format,mount --flake 'path:/tmp/nixos-config#carbon'
   ```

2. Install. The way in is the key in `config/ssh-keys`, which `base.nix` gives to both
   `joona` and `root`:

   ```sh
   sudo nixos-install --flake 'path:/tmp/nixos-config#<host>' --no-root-password
   ```

   Optionally set a console password too. On carbon it persists, because `mutableUsers` is
   on. Do it under the same keymap the machine boots with, or use letters and digits only:

   ```sh
   sudo nixos-enter --root /mnt -c 'passwd joona'
   ```

6. Reboot the machine and join the tailnet (preauth key generated with `headscale preauthkeys create`):

   ```sh
   sudo tailscale up --login-server https://head.joona.codes --auth-key <key>
   ```

7. `nixos-rebuild switch` on the vps so Prometheus picks up the `node-carbon` target.
