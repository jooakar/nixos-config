{
  lib,
  config,
  pkgs,
  ...
}:
let
  cfg = config.joona.services.qbittorrent;
  qbt = config.nixarr.qbittorrent;

  # nixarr binds the WebUI to the namespace address, not loopback, so this is
  # the API endpoint even from inside the namespace.
  api = "http://192.168.15.1:${toString qbt.qui.internalPort}";
  gateway = "10.2.0.1"; # Proton's NAT-PMP endpoint, the same on every server
in
{
  options.joona.services.qbittorrent.enable =
    lib.mkEnableOption "the Proton port forward nixarr does not do";

  config = lib.mkIf cfg.enable {
    systemd.services.qbittorrent.serviceConfig.UMask = "0002";

    # Proton hands out a forwarded port on a 60 second lease, so the port is not
    # known at build time and has to be renewed
    systemd.services.qbittorrent-natpmp = {
      description = "Renew the Proton VPN port forward for qbittorrent";
      after = [ "qbittorrent.service" ];
      partOf = [ "qbittorrent.service" ];
      wantedBy = [ "multi-user.target" ];
      vpnConfinement = {
        enable = true;
        vpnNamespace = "wg";
      };
      path = with pkgs; [
        libnatpmp
        iptables
        curl
        gawk
        jq
      ];
      serviceConfig = {
        Restart = "always";
        RestartSec = "10s";
      };
      script = ''
        iptables -N natpmp || true
        iptables -C INPUT -i wg0 -j natpmp || iptables -A INPUT -i wg0 -j natpmp

        while :; do
          port=$(natpmpc -a 1 0 tcp 60 -g ${gateway} | awk '/Mapped public port/ { print $4 }')
          natpmpc -a 1 0 udp 60 -g ${gateway} >/dev/null || true

          if [ -n "$port" ]; then
            iptables -F natpmp
            iptables -A natpmp -p tcp --dport "$port" -j ACCEPT
            iptables -A natpmp -p udp --dport "$port" -j ACCEPT

            have=$(curl -sf ${api}/api/v2/app/preferences | jq -r .listen_port || true)
            if [ "$have" != "$port" ]; then
              if curl -sf -X POST ${api}/api/v2/app/setPreferences \
                --data-urlencode "json={\"listen_port\":$port}"; then
                # A tracker only learns the port when a torrent announces, so
                # without this it keeps the stale one until the next interval.
                curl -sf -X POST ${api}/api/v2/torrents/reannounce -d hashes=all || true
                echo "forwarded port is now $port (was $have)"
              fi
            fi
          fi

          sleep 45
        done
      '';
    };
  };
}
