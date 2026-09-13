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
modules/nixos/apps/  one file per application running on the server
secrets/      agenix-encrypted env files, one rules file
terraform/    the UpCloud server, its firewall, and the DNS records
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

## What runs on the server

Everything is a NixOS service. There is no container orchestrator; `nixos-rebuild` is the
only thing that changes the machine.

| Module                        | What it runs                                            |
| ----------------------------- | ------------------------------------------------------- |
| `modules/nixos/web.nix`       | nginx and ACME. Every cert is issued over DNS-01.        |
| `modules/nixos/postgres.nix`  | PostgreSQL, one database per application                 |
| `modules/nixos/monitoring.nix`| Prometheus, node and postgres exporters, Loki, Alloy, Grafana |
| `modules/nixos/apps/*.nix`    | one podman container per application                     |
| `modules/nixos/deploy.nix`    | the restricted SSH identity CI deploys with              |

Only nginx listens on a public port. Everything else binds `127.0.0.1` and is reached
through a vhost, and vhosts built with `mkVhost { tailnetOnly = true; }` additionally
refuse anything outside `100.64.0.0/10`.

## Monitoring

Grafana is on `https://grafana.joona.codes`, tailnet only. Its admin credentials and secret
key come from `secrets/host/grafana.age` as `GF_*` environment variables, which Grafana
reads without any further wiring. Prometheus and Loki are provisioned as datasources.

Alloy tails the systemd journal and writes it to Loki. Podman logs container output to the
journal, so application logs land there too, labelled by `unit`.

Dashboards are not provisioned; `/var/lib/grafana` persists, so import them in the UI
(Node Exporter Full is 1860).

## Applications

One file per application under `modules/nixos/apps/`. It declares the container, its
nginx vhost, and the systemd ordering; the image tag is mutable and CI restarts the unit
after pushing to it, so releases never commit here. Every build is also pushed as
`:<sha>`, which is what to pin if a rollout has to be held back.

Adding an app: give it a database in `modules/nixos/databases.nix`, an env file in
`secrets/host/<app>.age`, a module in `modules/nixos/apps/<app>.nix`, and an import in
`modules/nixos/default.nix`.

### The deploy credential

CI restarts the container over SSH on the tailnet. `modules/nixos/deploy.nix` holds a
`deploy` user whose only authorized key is pinned to a forced command, so the key cannot
do anything else.

Put the public half in `modules/nixos/deploy.nix` as `ciKey`, and the private half in the
app CI's secrets. The workflow then ends with:

```sh
ssh deploy@vps.tailee6cd9.ts.net
```

## Prerequisites

`nix develop` gives you terraform, agenix, age and the UpCloud CLI.

### Secrets

Secrets are [agenix](https://github.com/ryantm/agenix) files under `secrets/`, one per
service or goal, each a list of `KEY=VALUE` lines:

```
secrets/env/<goal>.age      workstation only, sourced by scripts/tf.sh
secrets/host/<service>.age  workstation and vps, handed to a unit as an EnvironmentFile
```

`secrets/secrets.nix` lists both and decides who can decrypt what. Nothing unpacks these
files: the key names are chosen so the consuming service reads them straight out of its
own environment.

## PostgreSQL

Postgres runs on the host, not in a container, so no container holds state that cannot be
dropped and rebuilt.

### Per-service databases

`modules/nixos/databases.nix` is a list of names. Each one gets a database, a role of the
same name that owns it, and a password from `DB_PASSWORD` in `secrets/host/<name>.age`.
That is the same file the application container receives, and the password inside its
`DATABASE_URL` is the same value, so the role and the client cannot drift apart. Each
service only has access to its own database.

Containers reach the host at `host.containers.internal:5432` over the podman bridge, which
`pg_hba` admits for `10.88.0.0/16` and which the firewall trusts. 5432 is not open on any
other interface.

### Backups

`services.postgresqlBackup` dumps every database to `/var/backup/postgresql` at 03:00 daily.
That directory is on the root disk, so it survives a rebuild but not a Terraform destroy;
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
