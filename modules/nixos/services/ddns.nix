{ lib, config, ... }:
let
  cfg = config.joona.services.ddns;
in
{
  options.joona.services.ddns.enable =
    lib.mkEnableOption "keeping home.joona.codes pointed at this machine";

  config = lib.mkIf cfg.enable {
    age.secrets.cloudflare-ddns.file = ../../../secrets/host/cloudflare-ddns.age;
    services.cloudflare-dyndns = {
      enable = true;
      domains = [ "home.joona.codes" ];
      apiTokenFile = config.age.secrets.cloudflare-ddns.path;
      ipv4 = true;
      ipv6 = true;
    };
  };
}
