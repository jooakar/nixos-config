{
  config,
  lib,
  mkVhost,
  ...
}:
let
  image = "ghcr.io/jooakar/hundred:main";
  port = 3000;
  podman = "${config.virtualisation.podman.package}/bin/podman";

  # Both units are root, but say so rather than relying on podman's default
  # landing in /run, which a reboot empties.
  authFile = "/etc/containers/auth.json";
  envFile = config.age.secrets.hundred.path;
in
{
  # The tag is mutable and CI restarts the unit after pushing to it, so
  # releases never commit here. Every build is also pushed as :<sha>, which is
  # what to pin if a rollout has to be held back.
  virtualisation.oci-containers.backend = "podman";
  virtualisation.oci-containers.containers.hundred = {
    inherit image;
    pull = "always";
    ports = [ "127.0.0.1:${toString port}:${toString port}" ];
    environmentFiles = [ envFile ];
    environment = {
      MAIL_FROM_NAME = "Hundred";
      # adapter-node resolves request URLs against this, and better-auth builds
      # its callback and invitation links from it.
      ORIGIN = "https://beta.hundred.app";
    };
  };

  systemd.services.podman-hundred = {
    requires = [
      "podman-login.service"
      "postgresql-role-hundred.service"
    ];
    after = [
      "podman-login.service"
      "postgresql-role-hundred.service"
    ];
    environment.REGISTRY_AUTH_FILE = authFile;
    # Migrations run to completion before the server starts, so the app never
    # serves against a schema it has not migrated. Re-runs on every restart,
    # which is what a deploy is.
    serviceConfig.ExecStartPre = lib.mkAfter [
      "${podman} run --rm --pull=always --env-file=${envFile} ${image} node migrate.mjs"
    ];
  };

  systemd.services.podman-login = {
    description = "Authenticate podman against the image registry";
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];
    environment.REGISTRY_AUTH_FILE = authFile;
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      EnvironmentFile = config.age.secrets.ghcr.path;
    };
    script = ''
      ${podman} login ghcr.io --username "$GHCR_USERNAME" --password-stdin <<<"$GHCR_TOKEN"
    '';
  };

  age.secrets.ghcr.file = ../../../secrets/host/ghcr.age;

  services.nginx.virtualHosts."beta.hundred.app" = mkVhost { inherit port; };
}
