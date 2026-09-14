{
  pkgs,
  mkVhost,
  ...
}:
let
  port = 8080;
  domain = "head.joona.codes";

  dataDir = "/var/lib/headscale";
  backupDir = "/var/backup/headscale";
  dbPath = "${dataDir}/db.sqlite";

  publicIp = "185.20.137.173";
in
{
  services.headscale = {
    enable = true;
    address = "127.0.0.1";
    inherit port;

    settings = {
      server_url = "https://${domain}";
      database.type = "sqlite";

      dns = {
        magic_dns = true;
        # Must not be a parent of the server_url host, or clients would have to
        # resolve the control server through a tailnet they cannot join yet.
        base_domain = "ts.joona.codes";
        override_local_dns = true;
        # AdGuard on this same host, over the tailnet rather than loopback,
        # because this is the address handed to every other node too.
        nameservers.global = [ "100.64.0.1" ];
      };

      derp = {
        # Tailscale's public relays, kept as a fallback for when the vps is
        # unreachable. Drop this to relay exclusively through the embedded one.
        urls = [ "https://controlplane.tailscale.com/derpmap/default" ];

        server = {
          enabled = true;
          region_id = 999;
          region_code = "hel";
          region_name = "Helsinki";
          stun_listen_addr = "0.0.0.0:3478";
          ipv4 = publicIp;
          automatically_add_embedded_derp_region = true;
        };
      };
    };
  };

  # The relay itself rides the vhost below; only STUN needs a port of its own.
  networking.firewall.allowedUDPPorts = [ 3478 ];

  # The map connection is a long poll and the relay is a raw HTTP upgrade, both
  # of which nginx's buffering and 60s read timeout would cut.
  services.nginx.virtualHosts.${domain} = mkVhost {
    inherit port;
    extraConfig = ''
      proxy_buffering off;
      proxy_read_timeout 3600s;
      proxy_send_timeout 3600s;
    '';
  };

  # Losing the database or the noise key makes every node re-register, so it
  # lands next to the postgres dumps that get shipped off-box.
  systemd.tmpfiles.rules = [ "d ${backupDir} 0700 headscale headscale -" ];

  systemd.services.headscale-backup = {
    path = [
      pkgs.coreutils
      pkgs.sqlite
    ];
    serviceConfig = {
      Type = "oneshot";
      User = "headscale";
      Group = "headscale";
    };
    script = ''
      sqlite3 ${dbPath} ".backup '${backupDir}/db.sqlite'"
      install -m 0400 ${dataDir}/noise_private.key ${backupDir}/noise_private.key
      install -m 0400 ${dataDir}/derp_server_private.key ${backupDir}/derp_server_private.key
    '';
  };

  systemd.timers.headscale-backup = {
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = "03:15";
      Persistent = true;
    };
  };
}
