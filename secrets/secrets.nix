# One agenix file per service or goal, KEY=VALUE lines unless noted otherwise.
#
#   secrets/env/<goal>.age      sourced by scripts/tf.sh on the workstation
#   secrets/host/<service>.age  handed to a unit as an EnvironmentFile, or read
#                               from disk by it, on the host(s) listed below
let
  joona = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJSsuGp5k0SlENWdaMVCeuwiLurnwBBLaIRiXIx67JY3 jooakar";
  vps = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOPUVEtEqmwMuhGx5Nhd0Ij3Vv18JMIRDdVzTKs6oaTx root@vps";
  carbon = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJ0wkJyBy3yT2oLvUc49OyWwmRD4lwNdDakX0tve1VRo root@carbon";

  workstation.publicKeys = [ joona ];
  # A host only gets the secrets it actually runs something with.
  vpsHost.publicKeys = [
    joona
    vps
  ];
  carbonHost.publicKeys = [
    joona
    carbon
  ];
  bothHosts.publicKeys = [
    joona
    vps
    carbon
  ];

  env = [
    "upcloud-api" # UPCLOUD_TOKEN
    "r2-state" # AWS_ACCESS_KEY_ID / AWS_SECRET_ACCESS_KEY for the state bucket
    "cloudflare-api" # CLOUDFLARE_API_TOKEN, Zone:Read and DNS:Edit on both zones
  ];

  vpsEnv = [
    "ghcr" # GHCR_USERNAME / GHCR_TOKEN, read:packages is enough
    "grafana" # GF_SECURITY_ADMIN_USER / GF_SECURITY_ADMIN_PASSWORD
    # Per-application. DB_PASSWORD is what postgres.nix creates a role with
    "hundred"
  ];

  carbonEnv = [
    "protonvpn" # a wg-quick config file, not KEY=VALUE
    "mousehole" # MOUSEHOLE_AUTH_PASSWORD
  ];

  sharedEnv = [
    "acme" # CLOUDFLARE_DNS_API_TOKEN, the name lego reads
    "restic" # RESTIC_PASSWORD / AWS_ACCESS_KEY_ID / AWS_SECRET_ACCESS_KEY
  ];

  rule = prefix: recipients: name: {
    name = "${prefix}/${name}.age";
    value = recipients;
  };
in
builtins.listToAttrs (
  map (rule "env" workstation) env
  ++ map (rule "host" vpsHost) vpsEnv
  ++ map (rule "host" carbonHost) carbonEnv
  ++ map (rule "host" bothHosts) sharedEnv
)
