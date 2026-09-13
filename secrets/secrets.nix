# One agenix file per service or goal, each a list of KEY=VALUE lines.
#
#   secrets/env/<goal>.age      sourced by scripts/tf.sh on the workstation
#   secrets/host/<service>.age  handed to a unit on the vps as an EnvironmentFile
let
  joona = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJSsuGp5k0SlENWdaMVCeuwiLurnwBBLaIRiXIx67JY3 jooakar";
  vps = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOPUVEtEqmwMuhGx5Nhd0Ij3Vv18JMIRDdVzTKs6oaTx root@vps";

  workstation.publicKeys = [ joona ];
  host.publicKeys = [
    joona
    vps
  ];

  env = [
    "upcloud-api" # UPCLOUD_TOKEN
    "r2-state" # AWS_ACCESS_KEY_ID / AWS_SECRET_ACCESS_KEY for the state bucket
    "cloudflare-api" # CLOUDFLARE_API_TOKEN, Zone:Read and DNS:Edit on both zones
  ];

  hostEnv = [
    "acme" # CLOUDFLARE_DNS_API_TOKEN, the name lego reads
    "ghcr" # GHCR_USERNAME / GHCR_TOKEN, read:packages is enough
    "grafana" # GF_SECURITY_ADMIN_USER / GF_SECURITY_ADMIN_PASSWORD
    # Per-application. DB_PASSWORD is what postgres.nix creates a role with
    "hundred"
  ];

  rule = prefix: recipients: name: {
    name = "${prefix}/${name}.age";
    value = recipients;
  };
in
builtins.listToAttrs (map (rule "env" workstation) env ++ map (rule "host" host) hostEnv)
