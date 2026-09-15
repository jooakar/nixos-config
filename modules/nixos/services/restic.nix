{ config, hostname, ... }:
{
  # RESTIC_PASSWORD alongside the R2 credentials, so passwordFile stays null
  # and there is one file to rotate rather than two.
  age.secrets.restic.file = ../../../secrets/host/restic.age;

  # Services define their own backup with this
  _module.args.mkBackup =
    {
      paths,
      exclude ? [ ],
      startAt ? "*-*-* 04:00:00",
    }:
    {
      inherit paths exclude;

      repository = "s3:https://d247563982d77af7026e8d7168647e81.eu.r2.cloudflarestorage.com/backup/${hostname}";
      environmentFile = config.age.secrets.restic.path;

      initialize = true;
      timerConfig = {
        OnCalendar = startAt;
        RandomizedDelaySec = "30m";
        Persistent = true;
      };

      pruneOpts = [
        "--keep-daily 7"
        "--keep-weekly 5"
        "--keep-monthly 12"
      ];

      checkOpts = [ "--with-cache" ];
    };
}
