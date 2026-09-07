#!/usr/bin/env bash
# Decrypt the API credentials into the environment, then hand off to terraform.
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export RULES="$root/secrets/secrets.nix"

cd "$root/secrets"
set -a
eval "$(agenix -d upcloud-api.age)"
eval "$(agenix -d r2-state.age)"
eval "$(agenix -d cloudflare-api.age)"
set +a

cd "$root/terraform"
exec terraform "$@"
