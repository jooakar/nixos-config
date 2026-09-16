{
  config,
  lib,
  hostname,
  ...
}:
let
  cfg = config.joona.services.restic;

  toBackup = backup: {
    inherit (backup) paths exclude;

    repository = "s3:https://d247563982d77af7026e8d7168647e81.eu.r2.cloudflarestorage.com/backup/${hostname}";
    environmentFile = config.age.secrets.restic.path;

    initialize = true;
    timerConfig = {
      OnCalendar = backup.startAt;
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
in
{
  options.joona.services.restic.enable = lib.mkEnableOption "offsite backups to R2";

  options.joona.backups = lib.mkOption {
    default = { };
    description = ''
      What to keep offsite, keyed by backup name. One repository per host, and
      each entry becomes a `restic-backups-<name>` unit with its own wrapper.
    '';
    type = lib.types.attrsOf (
      lib.types.submodule {
        options = {
          paths = lib.mkOption {
            type = lib.types.listOf lib.types.str;
            description = "Directories to back up.";
          };

          exclude = lib.mkOption {
            type = lib.types.listOf lib.types.str;
            default = [ ];
            description = "Globs to leave out, caches and logs above all.";
          };

          startAt = lib.mkOption {
            type = lib.types.str;
            default = "*-*-* 04:00:00";
            description = "When to run, before a 30 minute random delay.";
          };
        };
      }
    );
  };

  config = lib.mkIf cfg.enable {
    # RESTIC_PASSWORD alongside the R2 credentials, so passwordFile stays null
    # and there is one file to rotate rather than two.
    age.secrets.restic.file = ../../../secrets/host/restic.age;

    services.restic.backups = builtins.mapAttrs (_: toBackup) config.joona.backups;
  };
}
