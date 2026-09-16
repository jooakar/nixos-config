{
  lib,
  config,
  ...
}:
let
  cfg = config.joona.services.mousehole;

  image = "docker.io/tmmrtn/mousehole:0.5.0";
  port = 5010;
  domain = "mousehole.joona.codes";
  stateDir = "/var/lib/mousehole";
in
{
  options.joona.services.mousehole.enable = lib.mkEnableOption "the tracker session keeper";

  config = lib.mkIf cfg.enable {
    virtualisation.oci-containers.containers.mousehole = {
      inherit image;
      environmentFiles = [ config.age.secrets.mousehole.path ];
      volumes = [ "${stateDir}:${stateDir}" ];

      environment = {
        TZ = config.time.timeZone;
        MOUSEHOLE_ALLOWED_HOSTS = domain;
        MOUSEHOLE_ALLOWED_ORIGINS = "https://${domain}";
        MOUSEHOLE_HTTPS_ONLY_COOKIES = "true";
      };

      extraOptions = [
        # Joins the tunnel rather than getting its own network, so its requests
        # carry the same source address as the torrent traffic.
        "--network=ns:/run/netns/wg"
        "--dns=10.2.0.1"
      ];
    };

    systemd.services.podman-mousehole = {
      after = [ "wg.service" ];
      bindsTo = [ "wg.service" ];
    };

    systemd.tmpfiles.settings.mousehole.${stateDir}."d" = {
      mode = "0700";
      user = "root";
      group = "root";
    };

    age.secrets.mousehole.file = ../../../secrets/host/mousehole.age;
    vpnNamespaces.wg.portMappings = [
      {
        from = port;
        to = port;
      }
    ];

    joona.services.web.enable = true;
    joona.vhosts.${domain} = {
      inherit port;
      host = "192.168.15.1";
    };
  };
}
