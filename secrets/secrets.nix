let
  joona = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJSsuGp5k0SlENWdaMVCeuwiLurnwBBLaIRiXIx67JY3 jooakar";
  vps = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOPUVEtEqmwMuhGx5Nhd0Ij3Vv18JMIRDdVzTKs6oaTx root@vps";

  workstation.publicKeys = [ joona ];
  host.publicKeys = [
    joona
    vps
  ];

  env = [
    "upcloud-api" # UPCLOUD_TOKEN=ucat_...
    "r2-state" # AWS_ACCESS_KEY_ID / AWS_SECRET_ACCESS_KEY for the state bucket
    "cloudflare-api" # CLOUDFLARE_API_TOKEN, Zone:Read and DNS:Edit on both zones
  ];

  cluster = {
    cert-manager = [ "CLOUDFLARE_API_TOKEN" ];

    hundred = [
      "DB_PASSWORD" # also what postgres.nix creates the role with
      "BETTER_AUTH_SECRET"
      "SENDGRID_API_KEY"
      "MAIL_FROM"
      "ghcr.docker-password"
    ];
  };

  rule = prefix: recipients: name: {
    name = "${prefix}/${name}.age";
    value = recipients;
  };
in
builtins.listToAttrs (
  map (rule "env" workstation) env
  ++ builtins.concatLists (
    builtins.attrValues (builtins.mapAttrs (namespace: map (rule "cluster/${namespace}" host)) cluster)
  )
)
