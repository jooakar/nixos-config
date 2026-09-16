{
  config,
  lib,
  ...
}:
let
  cfg = config.joona.apps.hundred;

  image = "ghcr.io/jooakar/hundred:main";
  port = 3000;
  podman = "${config.virtualisation.podman.package}/bin/podman";

  # Both units are root, but say so rather than relying on podman's default
  # landing in /run, which a reboot empties.
  authFile = "/etc/containers/auth.json";
  envFile = config.age.secrets.hundred.path;
in
{
  options.joona.apps.hundred.enable = lib.mkEnableOption "the hundred.app container";

  config = lib.mkIf cfg.enable {
    virtualisation.oci-containers.backend = "podman";
    virtualisation.oci-containers.containers.hundred = {
      inherit image;
      pull = "always";
      ports = [ "127.0.0.1:${toString port}:${toString port}" ];
      environmentFiles = [ envFile ];
      environment = {
        MAIL_FROM_NAME = "Hundred";
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
      serviceConfig.ExecStartPre = lib.mkAfter [
        "${podman} run --rm --pull=always --env-file=${envFile} ${image} node migrate.mjs"
      ];
    };

    systemd.services.podman-login = {
      description = "Authenticate podman against the image registry";
      after = [ "network-online.target" ];
      wants = [ "network-online.target" ];
      environment.REGISTRY_AUTH_FILE = authFile;
      # network-online.target is reached before DNS necessarily resolves, so the
      # first attempt after a boot can fail to look up the registry.
      startLimitIntervalSec = 300;
      startLimitBurst = 10;
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        Restart = "on-failure";
        RestartSec = "5s";
        EnvironmentFile = config.age.secrets.ghcr.path;
      };
      script = ''
        ${podman} login ghcr.io --username "$GHCR_USERNAME" --password-stdin <<<"$GHCR_TOKEN"
      '';
    };

    age.secrets.ghcr.file = ../../../secrets/host/ghcr.age;

    joona.services.web.enable = true;
    joona.vhosts."beta.hundred.app" = {
      inherit port;
      public = true;
    };
  };
}
