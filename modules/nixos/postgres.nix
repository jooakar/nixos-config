{
  config,
  lib,
  pkgs,
  clusterSecretName,
  k3sPodCidr,
  k3sHostAddr,
  ...
}:
let
  databases = import ./databases.nix;

  secretName = app: clusterSecretName app "DB_PASSWORD";
  passwordFile = app: config.age.secrets.${secretName app}.path;
in
{
  age.secrets = lib.genAttrs (map secretName databases) (_: {
    owner = "postgres";
    group = "postgres";
    mode = "0400";
  });

  # Gives pods a stable name for the host database
  services.k3s.manifests.postgres-host.content = [
    {
      apiVersion = "v1";
      kind = "Service";
      metadata = {
        name = "postgres";
        namespace = "default";
      };
      spec.ports = [
        {
          name = "postgres";
          port = 5432;
          targetPort = 5432;
        }
      ];
    }
    {
      apiVersion = "discovery.k8s.io/v1";
      kind = "EndpointSlice";
      metadata = {
        name = "postgres";
        namespace = "default";
        labels."kubernetes.io/service-name" = "postgres";
      };
      addressType = "IPv4";
      ports = [
        {
          name = "postgres";
          port = 5432;
        }
      ];
      endpoints = [
        {
          addresses = [ k3sHostAddr ];
          conditions.ready = true;
        }
      ];
    }
  ];

  # Runs on the host rather than k3s so that the cluster can be dropped at will
  services.postgresql = {
    enable = true;
    package = pkgs.postgresql_18;

    enableTCPIP = true;
    settings.password_encryption = "scram-sha-256";

    ensureDatabases = databases;
    ensureUsers = map (app: {
      name = app;
      ensureDBOwnership = true;
    }) databases;

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
