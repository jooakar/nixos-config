# Nix configuration

Hosts:

| Host         | Platform       | Built with                            |
| ------------ | -------------- | ------------------------------------- |
| `maxos`      | aarch64-darwin | `make darwin NIXNAME=maxos`           |
| `maxos-work` | aarch64-darwin | `make darwin NIXNAME=maxos-work`      |
| `vps`        | x86_64-linux   | `make nixos` (on the server)          |

The Macs and the server share `modules/packages.nix` and `modules/home-manager`; macOS-only
bits (Homebrew casks, fonts, aerospace/ghostty config, `pbcopy`, OrbStack) are gated on the
`isDarwin` flag passed through `specialArgs`.

## SSH keys

Each machine keeps its own keypair at `~/.ssh/id_ed25519`; private keys are never synced.
`config/ssh-keys/` holds the public halves, and every file in it is authorized on the server.
Adding a machine is dropping its `.pub` in that directory and rebuilding; revoking one is
deleting the file. The same public keys are the agenix recipients in the infra repo.

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

## k3s and Argo CD

`modules/nixos/k3s.nix` runs a single-node k3s server. Traefik is disabled: ingress is
cluster content and belongs in the GitOps repo.

Argo CD is installed declaratively through `services.k3s.autoDeployCharts`, which fetches the
`argo-cd` Helm chart at build time (pinned by version and hash) and hands k3s a `HelmChart`
resource. The app-of-apps root `Application` rides along in the chart's own `extraObjects`,
so it is rendered by the same Helm release and lands after the Argo CD CRDs exist. There is
no imperative bootstrap step: `nixos-rebuild switch` produces a cluster that syncs itself
from `clusters/<hostname>` in the GitOps repo.

To bump Argo CD, change `version` in `modules/nixos/k3s.nix` and refresh the hash:

```sh
helm pull --repo https://argoproj.github.io/argo-helm argo-cd --version <new>
nix hash file argo-cd-<new>.tgz
```

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

## PostgreSQL

Postgres runs on the host, not in the cluster, so nothing in k3s holds state that cannot be
dropped and rebuilt from git. It listens on all interfaces because the cni0 gateway address
does not exist until k3s has started; the firewall is what keeps 5432 off the public
interface. Only `cni0` and `tailscale0` are trusted, so pods can reach it and the internet
cannot.

Pods reach the host at the cni0 gateway, `10.42.0.1:5432`. Give that a stable name from the
GitOps repo rather than from here, since a Service is droppable cluster content:

```yaml
apiVersion: v1
kind: Service
metadata:
  name: postgres
spec:
  ports: [{ port: 5432 }]
---
apiVersion: v1
kind: Endpoints
metadata:
  name: postgres
subsets:
  - addresses: [{ ip: 10.42.0.1 }]
    ports: [{ port: 5432 }]
```

Databases and roles are not declared in Nix, because roles need passwords and those would end
up world-readable in the nix store. Create them once by hand (or add sops-nix later):

```sh
sudo -u postgres createuser --pwprompt myapp
sudo -u postgres createdb -O myapp myapp
```

`services.postgresqlBackup` dumps every database to `/var/backup/postgresql` at 03:00 daily.
That directory is on the root disk, so it survives a k3s wipe but not a Terraform destroy;
ship it off-box with the `rclone` that is already in the package set.
