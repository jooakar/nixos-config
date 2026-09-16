{
  imports = [
    ../modules/packages/common.nix
    ../modules/packages/server.nix
    ../modules/home-manager
    ../modules/nixos/base.nix
    ../modules/nixos/hardware/vps.nix
    ../modules/nixos/disko/vps.nix
  ];

  joona.services = {
    headscale.enable = true;
    adguard.enable = true;
    postgres.enable = true;
    monitoring.enable = true;
    node-exporter.enable = true;
    deploy.enable = true;
  };

  joona.apps.hundred.enable = true;
}
