# Nix configuration

Hosts:

| Host         | Platform       | What it is                | Built with                       |
| ------------ | -------------- | ------------------------- | -------------------------------- |
| `maxos`      | aarch64-darwin | personal laptop           | `make darwin NIXNAME=maxos`      |
| `maxos-work` | aarch64-darwin | work laptop               | `make darwin NIXNAME=maxos-work` |
| `vps`        | x86_64-linux   | UpCloud server            | `make nixos NIXNAME=vps`         |
| `carbon`     | x86_64-linux   | X1 Carbon gen 5, at home  | `make nixos NIXNAME=carbon`      |

Darwin-only bits are gated on the `isDarwin` flag passed through `specialArgs`.

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

Nothing is switched on by a profile flag: a host runs a service because
`hosts/<name>.nix` imports it. `modules/packages/*.nix` are ordinary modules that add to
`environment.systemPackages`, so a host imports the sets it wants instead of concatenating
lists. `vps` and `carbon` both take `common` + `server`; the darwin hosts take `common` +
`workstation`, and their personal/work difference is only the homebrew cask overlay in
`modules/darwin/<profile>.nix`.

## Deploys

Terraform provisions the machine; it does not deploy config. Use `make nixos NIXNAME=<host>`
on the machine itself, or remotely:

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
| `services/web.nix`           | nginx and ACME. Every cert is issued over DNS-01.        |
| `services/headscale.nix`     | Headscale, the tailnet's coordination server and relay   |
| `services/adguard.nix`       | AdGuard Home, the tailnet's resolver                     |
| `services/postgres.nix`      | PostgreSQL, one database per application                 |
| `services/monitoring.nix`    | Prometheus, the postgres exporter, Loki, Alloy, Grafana  |
| `services/node-exporter.nix` | the node exporter. `carbon` runs this one too.           |
| `apps/*.nix`                 | one podman container per application                     |
| `services/deploy.nix`        | the restricted SSH identity CI deploys with              |

Only nginx listens on a public port. Everything else binds `127.0.0.1` and is reached
through a vhost, and vhosts built with `mkVhost { tailnetOnly = true; }` additionally
refuse anything outside `100.64.0.0/10`.

## The tailnet

Nodes join with a pre-auth key. Setup:

```sh
sudo headscale users create <user>
sudo headscale preauthkeys create --user <user> --reusable --expiration 24h
```

then on the node, `tailscale up --login-server https://head.joona.codes --auth-key <key>`

Relaying goes through the embedded DERP server on the vps, with Tailscale's public relays kept
as a fallback in `modules/nixos/headscale.nix`.

Headscale's database and its noise key live in `/var/lib/headscale`, and losing them makes every
node re-register. A timer copies both into `/var/backup/headscale` at 03:15, next to the
postgres dumps, which is what gets shipped off-box.

## Monitoring

Grafana is on `https://grafana.joona.codes`, tailnet only. Its admin credentials and secret
key come from `secrets/host/grafana.age` as `GF_*` environment variables, which Grafana
reads without any further wiring. Prometheus and Loki are provisioned as datasources.

Alloy tails the systemd journal and writes it to Loki. Podman logs container output to the
journal, so application logs land there too, labelled by `unit`.

Dashboards are provisioned read-only from `config/grafana/dashboards`; to change one, edit a
copy in the UI, export it, and commit the JSON. `/var/lib/grafana` persists, so anything
imported by hand in the UI survives too.

`carbon` is scraped over the tailnet at `carbon.ts.joona.codes:9100` as the `node-carbon`
job. Every host that imports `services/node-exporter.nix` binds 9100 on all interfaces;
9100 is never in `allowedTCPPorts`, so only loopback and the tailnet reach it.

## Applications

One file per application under `modules/nixos/apps/`. It declares the container, its
nginx vhost, and the systemd ordering; the image tag is mutable and CI restarts the unit
after pushing to it, so releases never commit here. Every build is also pushed as
`:<sha>`, which is what to pin if a rollout has to be held back.

Adding an app: give it a database in `modules/nixos/services/databases.nix`, an env file in
`secrets/host/<app>.age`, a module in `modules/nixos/apps/<app>.nix`, and an import in
`hosts/vps.nix`.

### The deploy credential

CI restarts the container over SSH on the tailnet. `modules/nixos/deploy.nix` holds a
`deploy` user whose only authorized key is pinned to a forced command, so the key cannot
do anything else.

Put the public half in `modules/nixos/deploy.nix` as `ciKey`, and the private half in the
app CI's secrets. The workflow then ends with:

```sh
ssh deploy@vps.ts.joona.codes
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

5. `ssh <user>@<ip>`, then join the tailnet with a key from `headscale preauthkeys create`:

   ```sh
   sudo tailscale up --login-server https://head.joona.codes --auth-key <key>
   ```

   `sudo headscale nodes list` then gives the address that `var.tailscale_ip` has to hold.

## carbon

An X1 Carbon gen 5 at home, headless, on the tailnet. It runs no service the vps already
runs; it is a client of headscale and AdGuard and a scrape target for Prometheus. Its root
disk is LUKS with ext4 inside (`modules/nixos/disko/carbon.nix`); the passphrase is typed at
boot. The lid is ignored so closing it does not suspend the machine, and TLP keeps the
battery between 75% and 80% rather than holding it at full charge.

`console.keyMap = "fi"` there, which also reaches the initrd, so the LUKS prompt reads the
keycaps rather than defaulting to `us`. The vps is left alone: its console is UpCloud's
browser one, which applies a layout of its own and would translate twice.

It is also the one host where `users.mutableUsers` is back on. The vps is publicly reachable
and key-only, so it stays declarative; on carbon, `mutableUsers = false` rewrites every
shadow entry to `!` on each activation, and activation runs on *every boot*, so a password
set with `passwd` never survives to the login prompt. Since carbon is physically in reach,
the nixpkgs default applies and `passwd` sticks.

None of that is normally load-bearing: ethernet comes up on its own and ssh is the way in.
If it ever does break, the recovery path is the USB installer plus `nixos-enter`, which
gives root without any password.

External drives and the media library are not configured yet.

### Installing it

1. Write a NixOS minimal x86_64 ISO to a USB stick (`diskutil unmountDisk /dev/diskN` then
   `sudo dd if=<iso> of=/dev/rdiskN bs=4m`).
2. Boot it (F12 for the boot menu, Secure Boot off). Plug in ethernet; the gen 5 has no port
   of its own, so this is the Lenovo adapter or a USB dongle. NetworkManager runs on the
   installer and picks a wired link up by itself. For wifi instead, the `nixos` user is
   already in the `networkmanager` group, so `nmtui` works without sudo.

   Whatever you do here does not carry over: the installer's connection lives on its own
   tmpfs. Ethernet is what makes the installed system reachable on first boot.
3. Check the disk path with `lsblk`; `flake.nix` assumes `/dev/nvme0n1`.
4. Clone this repo onto the installer, then partition, format and mount:

   ```sh
   echo -n '<luks passphrase>' > /tmp/luks.key
   sudo nix --experimental-features 'nix-command flakes' run github:nix-community/disko -- \
     --mode destroy,format,mount --flake 'path:/tmp/nixos-config#carbon'
   ```

5. Install. The way in is the key in `config/ssh-keys`, which `base.nix` gives to both
   `joona` and `root`:

   ```sh
   sudo nixos-install --flake 'path:/tmp/nixos-config#carbon' --no-root-password
   ```

   Optionally set a console password too. On carbon it persists, because `mutableUsers` is
   on. Do it under the same keymap the machine boots with, or use letters and digits only:

   ```sh
   sudo nixos-enter --root /mnt -c 'passwd joona'
   ```

6. Reboot, pull the USB, unlock at the LUKS prompt, then ssh in over ethernet and join the
   tailnet with a key from `headscale preauthkeys create`:

   ```sh
   sudo tailscale up --login-server https://head.joona.codes --auth-key <key>
   ```

7. `nixos-rebuild switch` on the vps so Prometheus picks up the `node-carbon` target.
