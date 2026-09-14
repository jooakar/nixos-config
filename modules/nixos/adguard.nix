{ mkVhost, ... }:
let
  port = 3002; # 3000 is the hundred container, 3001 grafana
  domain = "dns.joona.codes";
in
{
  services.adguardhome = {
    enable = true;
    host = "127.0.0.1";
    inherit port;

    # Declared keys win on every start, but the web interface stays usable for
    # the things that are tedious to express here: one-off allow rules while
    # something is broken, client names, the query log.
    mutableSettings = true;

    settings = {
      dns = {
        # tailscale0 and podman0 are the only trusted interfaces and 53 is
        # never opened on the public one, so this is not an open resolver.
        bind_hosts = [ "0.0.0.0" ];
        port = 53;

        upstream_dns = [
          "https://dns.cloudflare.com/dns-query"
          "https://dns.quad9.net/dns-query"
        ];
        # Resolves the upstream hostnames themselves, so it cannot be DoH.
        bootstrap_dns = [
          "1.1.1.1"
          "9.9.9.9"
        ];

        # Every client arrives as its own tailnet address, and the default 20
        # queries per second is well inside what one laptop does in a burst.
        ratelimit = 0;
      };

      filtering = {
        protection_enabled = true;
        filtering_enabled = true;
        filters_update_interval = 24;
      };

      filters = [
        {
          enabled = true;
          id = 1;
          name = "AdGuard DNS filter";
          url = "https://adguardteam.github.io/HostlistsRegistry/assets/filter_1.txt";
        }
        {
          enabled = true;
          id = 2;
          name = "OISD Big";
          url = "https://big.oisd.nl";
        }
      ];
    };
  };

  services.nginx.virtualHosts.${domain} = mkVhost {
    inherit port;
    tailnetOnly = true;
  };
}
