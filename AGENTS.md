# nixos-config

## Deploying

Deploys are manual: pushing to main changes no host.

- **On carbon** (`hostname` prints `carbon`), apply your change with `sudo nixos-rebuild switch --flake .#carbon` once `nixos-rebuild build --flake .#carbon` passes. Ask me before switching. The switch restarts changed services; if `t3code` is one of them, your session drops mid-switch, so reconnect and check `systemctl --failed`.
- **Every other host** I deploy myself, with `make remote HOST=<host>` or `make darwin HOST=<host>`.
