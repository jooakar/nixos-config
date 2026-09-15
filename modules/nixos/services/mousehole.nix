{
  config,
  mkVhost,
  ...
}:
let
  # Pinned rather than :latest. This is a third party image, and the repo's own
  # mutable tag is only appropriate where CI controls what it points at.
  image = "docker.io/tmmrtn/mousehole:0.5.0";
  port = 5010;
  domain = "mousehole.joona.codes";
  stateDir = "/var/lib/mousehole";
in
{
  virtualisation.oci-containers.containers.mousehole = {
    inherit image;
    environmentFiles = [ config.age.secrets.mousehole.path ];
    volumes = [ "${stateDir}:${stateDir}" ];

    environment = {
      TZ = config.time.timeZone;
      # Both default to localhost only, which rejects everything arriving
      # through the vhost below.
      MOUSEHOLE_ALLOWED_HOSTS = domain;
      MOUSEHOLE_ALLOWED_ORIGINS = "https://${domain}";
      MOUSEHOLE_HTTPS_ONLY_COOKIES = "true";
    };

    extraOptions = [
      # Joins the tunnel rather than getting its own network, so its requests
      # to the tracker carry the same source address as the torrent traffic.
      "--network=ns:/run/netns/wg"
      # Without this podman copies the host's resolv.conf in, which points at
      # AdGuard on the tailnet. The kill switch drops that, and the namespace
      # only permits DNS to Proton's resolver.
      "--dns=10.2.0.1"
    ];
  };

  # The namespace has to exist before the container can join it, and the
  # container has to go away with it rather than linger with no network.
  systemd.services.podman-mousehole = {
    after = [ "wg.service" ];
    bindsTo = [ "wg.service" ];
  };

  # Holds the tracker session cookie, which the tracker rotates on every update, so losing
  # it means going back to the browser for a new one.
  systemd.tmpfiles.settings.mousehole.${stateDir}."d" = {
    mode = "0700";
    user = "root";
    group = "root";
  };

  age.secrets.mousehole.file = ../../../secrets/host/mousehole.age;

  # Reached the same way as qBittorrent's WebUI: the port mapping is what opens
  # it on the namespace side of the veth pair.
  vpnNamespaces.wg.portMappings = [
    {
      from = port;
      to = port;
    }
  ];

  services.nginx.virtualHosts.${domain} = mkVhost {
    inherit port;
    # In the namespace, so nginx reaches it across the veth pair. The port
    # mapping above DNATs in PREROUTING, which loopback traffic never traverses.
    host = "192.168.15.1";
    tailnetOnly = true;
  };
}
