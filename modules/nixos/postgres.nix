{ pkgs, k3sPodCidr, ... }:
{
  # Runs on the host, not in k3s, so the cluster holds no state that cannot be
  # dropped and rebuilt from git.
  services.postgresql = {
    enable = true;
    # Pinned: a major version bump needs a manual pg_upgrade of the data dir.
    package = pkgs.postgresql_18;

    # Listens on every interface rather than the cni0 gateway address, which
    # does not exist until k3s has started. The firewall keeps 5432 off the
    # public interface; only cni0 is trusted.
    enableTCPIP = true;
    settings.password_encryption = "scram-sha-256";
    authentication = ''
      host all all ${k3sPodCidr} scram-sha-256
    '';
  };

  services.postgresqlBackup = {
    enable = true;
    startAt = "*-*-* 03:00:00";
    location = "/var/backup/postgresql";
  };
}
