{
  config,
  lib,
  pkgs,
  ...
}:
let
  databases = import ./databases.nix;

  # The same file the application gets. DB_PASSWORD in it is the password
  # inside its DATABASE_URL, so the role and the client cannot drift apart.
  envFile = app: config.age.secrets.${app}.path;

  # Containers reach the host on the default podman bridge.
  podmanCidr = "10.88.0.0/16";
in
{
  age.secrets = lib.genAttrs databases (app: {
    file = ../../secrets/host/${app}.age;
    owner = "postgres";
    group = "postgres";
    mode = "0400";
  });

  # Runs on the host rather than in a container so that nothing containerised
  # holds state that cannot be dropped and rebuilt.
  services.postgresql = {
    enable = true;
    package = pkgs.postgresql_18;

    # Binding the bridge address directly would make startup depend on podman
    # having created it, so listen everywhere; the firewall is what keeps 5432
    # off every interface but podman0 and the tailnet.
    enableTCPIP = true;
    settings.password_encryption = "scram-sha-256";

    ensureDatabases = databases;
    ensureUsers = map (app: {
      name = app;
      ensureDBOwnership = true;
    }) databases;

    authentication = lib.concatMapStrings (app: ''
      host ${app} ${app} ${podmanCidr} scram-sha-256
    '') databases;
  };

  # One unit per application, so each only ever sees its own env file.
  systemd.services = lib.listToAttrs (
    map (app: {
      name = "postgresql-role-${app}";
      value = {
        description = "Apply the ${app} database role password and grants";
        after = [ "postgresql.service" ];
        requires = [ "postgresql.service" ];
        wantedBy = [ "multi-user.target" ];
        path = [
          config.services.postgresql.package
          pkgs.coreutils
        ];
        serviceConfig = {
          Type = "oneshot";
          User = "postgres";
          RemainAfterExit = true;
          EnvironmentFile = envFile app;
        };
        script = ''
          psql -v ON_ERROR_STOP=1 --no-psqlrc <<'SQL'
          \set password `printenv DB_PASSWORD`
          ALTER ROLE "${app}" WITH LOGIN PASSWORD :'password';
          REVOKE ALL ON DATABASE "${app}" FROM PUBLIC;
          GRANT CONNECT ON DATABASE "${app}" TO "${app}";
          SQL
        '';
      };
    }) databases
  );

  services.postgresqlBackup = {
    enable = true;
    startAt = "*-*-* 03:00:00";
    location = "/var/backup/postgresql";
  };
}
