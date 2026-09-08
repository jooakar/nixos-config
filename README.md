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

The initial admin password can be fetched with:

```sh
kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath='{.data.password}' | base64 -d
```

## Applications

One Argo CD `Application` per app under `cluster/vps/`, pointing at that app's manifests in
`cluster/apps/`. Argo owns the manifests and CI owns the releases. A deployment tracks a
mutable image tag with `imagePullPolicy: Always`, so shipping a new build is pushing that tag
and restarting the deployment.

Adding an app: give it a database in `modules/nixos/databases.nix`, manifests in
`cluster/apps/<app>/`, an `Application` in `cluster/vps/`, and its credentials in
`secrets/cluster/<app>/` (below). Copy `cluster/apps/hundred/ci-deploy.yaml` across with the
namespace changed; the verbs it binds are shared, so only those three objects repeat.

### The deploy credential

CI authenticates with a service account token. Mint the kubeconfig once, on the server, and
put it in the app repo's Actions secrets as `K8S_DEPLOY_KUBECONFIG`:

```sh
ns=hundred
ca=$(kubectl -n $ns get secret ci-deploy-token -o jsonpath='{.data.ca\.crt}')
token=$(kubectl -n $ns get secret ci-deploy-token -o jsonpath='{.data.token}' | base64 -d)
cat <<EOF | base64 -w0
apiVersion: v1
kind: Config
current-context: ci
clusters: [{name: vps, cluster: {server: https://vps.tailee6cd9.ts.net:6443, certificate-authority-data: $ca}}]
users: [{name: ci-deploy, user: {token: $token}}]
contexts: [{name: ci, context: {cluster: vps, user: ci-deploy, namespace: $ns}}]
EOF
```

The runner reaches port 6443 over tailscale, so the repo also needs `TS_OAUTH_CLIENT_ID` and
`TS_OAUTH_SECRET` from a tailnet OAuth client that can issue `tag:ci` nodes.

## Prerequisites

`nix develop` gives you terraform, agenix, kubectl, helm, argocd and k9s.

### Secrets

Secrets are [agenix](https://github.com/ryantm/agenix) files under `secrets/`

```
secrets/env/<name>.age                 list of KEY=VALUE pairs
secrets/cluster/<namespace>/<KEY>.age  one bare value per file
```

Everything in `cluster/` is published by `modules/nixos/cluster-secrets.nix`, which reads 
the tree at build time and applies it once k3s is up. Each namespace gets a single 
secret called `env` whose keys are the file names.

## PostgreSQL

Postgres runs on the host, not in the cluster, so nothing in k3s holds state that cannot be
dropped and rebuilt from git. It listens on every interface, because the cni0 gateway address
does not exist until k3s has started; the firewalls are the only thing keeping 5432 off the
public interface.

### Per-service databases

`modules/nixos/databases.nix` is a list of names. Each one gets a database, a role of the
same name that owns it, and a password from `secrets/cluster/<name>/DB_PASSWORD.age`. Each
service only has access to its own database.

That is the same file the cluster publishes to the application, so the role password and the
password the pod connects with cannot drift apart. Pods reach the host at
`postgres.default.svc.cluster.local:5432` through the service in `modules/nixos/postgres.nix`.

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
