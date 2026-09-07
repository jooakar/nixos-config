{
  config,
  lib,
  pkgs,
  flakeRoot,
  k3sPodCidr,
  ...
}:
let
  databases = import ./databases.nix;

  secretName = app: "pg-${app}";
  passwordFile = app: config.age.secrets.${secretName app}.path;
in
{
  age.secrets = lib.genAttrs (map secretName databases) (name: {
    file = flakeRoot + "/secrets/${name}.age";
    owner = "postgres";
    group = "postgres";
    mode = "0400";
  });

  # Runs on the host rather than k3s so that the cluster can be dropped at will
  services.postgresql = {
    enable = true;
    package = pkgs.postgresql_18;

    # Listens on every interface rather than the cni0 gateway address, which
    # does not exist until k3s has started. The firewall keeps 5432 off the
    # public interface; only cni0 and tailscale0 are trusted.
    enableTCPIP = true;
    settings.password_encryption = "scram-sha-256";

    ensureDatabases = databases;
    ensureUsers = map (app: {
      name = app;
      ensureDBOwnership = true;
    }) databases;

    # One rule per app: a role may only authenticate against its own database,
    # and only from the pod network. Anything not listed here falls through to
    # the module defaults, which are socket-only peer auth for admin access.
    authentication = lib.concatMapStrings (app: ''
      host ${app} ${app} ${k3sPodCidr} scram-sha-256
    '') databases;
  };

  # Add roles and passwords for each application
  systemd.services.postgresql-role-passwords = lib.mkIf (databases != [ ]) {
    description = "Apply application database role passwords and grants";
    after = [ "postgresql.service" ];
    requires = [ "postgresql.service" ];
    wantedBy = [ "multi-user.target" ];
    path = [ config.services.postgresql.package ];
    serviceConfig = {
      Type = "oneshot";
      User = "postgres";
      RemainAfterExit = true;
    };
    script = lib.concatMapStrings (app: ''
      psql -v ON_ERROR_STOP=1 --no-psqlrc <<'SQL'
      \set password `cat ${passwordFile app}`
      ALTER ROLE "${app}" WITH LOGIN PASSWORD :'password';
      REVOKE ALL ON DATABASE "${app}" FROM PUBLIC;
      GRANT CONNECT ON DATABASE "${app}" TO "${app}";
      SQL
    '') databases;
  };

  services.postgresqlBackup = {
    enable = true;
    startAt = "*-*-* 03:00:00";
    location = "/var/backup/postgresql";
  };
}
