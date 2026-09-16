{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.joona.services.headscale;

  port = 8080;
  domain = "head.joona.codes";

  dataDir = "/var/lib/headscale";
  backupDir = "/var/backup/headscale";
  dbPath = "${dataDir}/db.sqlite";

  publicIp = "185.20.137.173";
in
{
  options.joona.services.headscale.enable =
    lib.mkEnableOption "Headscale, the tailnet's coordination server";

  config = lib.mkIf cfg.enable {
    services.headscale = {
      enable = true;
      address = "127.0.0.1";
      inherit port;

      settings = {
        server_url = "https://${domain}";
        database.type = "sqlite";

        dns = {
          magic_dns = true;
          base_domain = "ts.joona.codes";
          override_local_dns = true;
          # AdGuard on this same host
          nameservers.global = [ "100.64.0.1" ];
        };

        derp = {
          # Fallback Tailscale public relay
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

    networking.firewall.allowedUDPPorts = [ 3478 ];

    joona.services.web.enable = true;
    joona.vhosts.${domain} = {
      inherit port;
      public = true;
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
  };
}
