#!/usr/bin/env bash
# Decrypt the API credentials into the environment, then hand off to terraform.
# Everything in secrets/env is sourced, so a new credential is a new file there.
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export RULES="$root/secrets/secrets.nix"

cd "$root/secrets"
set -a
for secret in env/*.age; do
  eval "$(agenix -d "$secret")"
done
set +a

cd "$root/terraform"
exec terraform "$@"
