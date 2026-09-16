{
  config,
  inputs,
  lib,
  ...
}:
let
  cfg = config.joona.services.nixarr;
  stateDir = "/data/.state/nixarr";
in
{
  imports = [ inputs.nixarr.nixosModules.default ];

  options.joona.services.nixarr.enable = lib.mkEnableOption "the nixarr media stack";

  config = lib.mkIf cfg.enable {
    joona.services.web.enable = true;
    joona.services.restic.enable = true;

    joona.vhosts = {
      "tv.joona.codes" = {
        port = 8096; # jellyfin
        public = true;
        loginPaths = [ "/Users/AuthenticateByName" ];
        # Buffering a transcode to disk before forwarding it adds seek latency,
        # and the default body size rejects artwork and subtitle uploads.
        extraConfig = ''
          proxy_buffering off;
          client_max_body_size 20M;
        '';
      };
      "books.joona.codes" = {
        port = 9292; # audiobookshelf
        public = true;
        loginPaths = [ "/login" ];
        extraConfig = "client_max_body_size 2G;"; # uploads are whole books
      };
      "seerr.joona.codes" = {
        port = 5055;
        public = true;
        loginPaths = [
          "/api/v1/auth/jellyfin"
          "/api/v1/auth/local"
        ];
      };
      "shelfmark.joona.codes" = {
        port = 8084;
        public = true;
        loginPaths = [ "/login" ];
      };
      # qui runs on the host and proxies qbittorrent inside the namespace.
      "qbt.joona.codes".port = 5252;
      "prowlarr.joona.codes".port = 9696;
      "sonarr.joona.codes".port = 8989;
      "radarr.joona.codes".port = 7878;
      "bazarr.joona.codes".port = 6767;
    };

    age.secrets.protonvpn.file = ../../../secrets/host/protonvpn.age;

    nixarr = {
      enable = true;
      mediaUsers = [ "joona" ];

      mediaDir = "/data/media";
      inherit stateDir;

      vpn = {
        enable = true;
        wgConf = config.age.secrets.protonvpn.path;
        exposeOnLAN = false;
      };

      jellyfin.enable = true;
      audiobookshelf.enable = true;

      # Confine torrent client to use VPN
      qbittorrent = {
        enable = true;
        vpn.enable = true;
        qui.enable = true;

        peerPort = 48712;

        privateTrackers.disableDhtPex = true;
        torrentQueueing.enable = false;
      };

      prowlarr.enable = true;
      sonarr.enable = true;
      radarr.enable = true;
      bazarr.enable = true;
      seerr.enable = true;

      recyclarr = {
        enable = true;
        configuration = {
          sonarr.series = {
            base_url = "http://127.0.0.1:8989";
            api_key = "!env_var SONARR_API_KEY";
            quality_definition.type = "series";
            quality_profiles = [
              {
                trash_id = "72dae194fc92bf828f32cde7744e51a1"; # WEB-1080p
                reset_unmatched_scores.enabled = true;
              }
            ];
            custom_format_groups.add = [
              { trash_id = "158188097a58d7687dee647e04af0da3"; } # Golden Rule HD
              { trash_id = "74aff4168620ed49dcc67e92b2c2a5b4"; } # Language Profiles
              { trash_id = "85fae4a2294965b75710ef2989c850eb"; } # Streaming boost
              { trash_id = "59c3af66780d08332fdc64e68297098f"; } # Unwanted Formats
            ];
          };
          radarr.movies = {
            base_url = "http://127.0.0.1:7878";
            api_key = "!env_var RADARR_API_KEY";
            quality_definition.type = "movie";
            quality_profiles = [
              {
                trash_id = "d1d67249d3890e49bc12e275d989a7e9"; # HD Bluray + WEB
                reset_unmatched_scores.enabled = true;
              }
            ];
            custom_format_groups.add = [
              { trash_id = "f8bf8eab4617f12dfdbd16303d8da245"; } # Golden Rule HD
              { trash_id = "a3ac6af01d78e4f21fcb75f601ac96df"; } # Unwanted Formats
            ];
          };
        };
      };
      shelfmark.enable = true;
    };

    services.shelfmark.environment.AUTH_METHOD = "builtin";

    joona.backups.nixarr = {
      paths = [ stateDir ];
      exclude = [
        "${stateDir}/jellyfin/cache"
        "${stateDir}/*/log"
        "${stateDir}/*/logs"
      ];
    };
  };
}
