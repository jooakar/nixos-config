{
  config,
  pkgs,
  ...
}:
let
  cfg = config.nixarr.qbittorrent;

  # nixarr binds the WebUI to the namespace address, not loopback, so this is
  # the API endpoint even from inside the namespace.
  api = "http://192.168.15.1:${toString cfg.qui.internalPort}";
  gateway = "10.2.0.1"; # Proton's NAT-PMP endpoint, the same on every server
in
{
  systemd.services.qbittorrent.serviceConfig.UMask = "0002";

  # Proton hands out a forwarded port on a 60 second lease, so the port is not
  # known at build time and has to be renewed
  systemd.services.qbittorrent-natpmp = {
    description = "Renew the Proton VPN port forward for qbittorrent";
    after = [ "qbittorrent.service" ];
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
      current=

      # NAT-PMP is v4 only, but qbittorrent listens on the same port for both
      # families and v6 needs no mapping, just an accept.
      for t in iptables ip6tables; do
        $t -N natpmp || true
        $t -C INPUT -i wg0 -j natpmp || $t -A INPUT -i wg0 -j natpmp
      done

      # The namespace's v6 default route has been observed missing after some
      # starts, which silently drops v6 seeding. Idempotent, so it is a no-op
      # when vpn-up got it right.
      ip -6 route show default | grep -q wg0 || ip -6 route add default dev wg0

      while :; do
        port=$(natpmpc -a 1 0 tcp 60 -g ${gateway} | awk '/Mapped public port/ { print $4 }')
        natpmpc -a 1 0 udp 60 -g ${gateway} >/dev/null || true

        if [ -n "$port" ]; then
          if [ "$port" != "$current" ]; then
            for t in iptables ip6tables; do
              $t -F natpmp
              $t -A natpmp -p tcp --dport "$port" -j ACCEPT
              $t -A natpmp -p udp --dport "$port" -j ACCEPT
            done
            current=$port
          fi

          # Restarting qbittorrent rewrites its port from the store, so compare
          # against what it is actually listening on rather than trusting that
          # the last push stuck.
          have=$(curl -sf ${api}/api/v2/app/preferences | jq -r .listen_port || true)
          if [ "$have" != "$port" ]; then
            curl -sf -X POST ${api}/api/v2/app/setPreferences \
              --data-urlencode "json={\"listen_port\":$port}" \
              && echo "forwarded port is now $port (was $have)"
          fi
        fi

        sleep 45
      done
    '';
  };
}
