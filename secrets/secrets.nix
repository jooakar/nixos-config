let
  joona = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJSsuGp5k0SlENWdaMVCeuwiLurnwBBLaIRiXIx67JY3 jooakar";
  vps = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOPUVEtEqmwMuhGx5Nhd0Ij3Vv18JMIRDdVzTKs6oaTx root@vps";

  workstation.publicKeys = [ joona ];
  host.publicKeys = [
    joona
    vps
  ];

  databases = import ../modules/nixos/databases.nix;
in
{
  # UPCLOUD_TOKEN=ucat_...
  "upcloud-api.age" = workstation;

  # AWS_ACCESS_KEY_ID=... / AWS_SECRET_ACCESS_KEY=... for the R2 state bucket
  "r2-state.age" = workstation;

  # CLOUDFLARE_API_TOKEN=... with Zone:Read and DNS:Edit on both zones
  "cloudflare-api.age" = workstation;

  # The same token, bare, published into the cluster for cert-manager DNS-01
  "cloudflare-dns.age" = host;
}
// builtins.listToAttrs (
  map (app: {
    name = "pg-${app}.age";
    value = host;
  }) databases
)
