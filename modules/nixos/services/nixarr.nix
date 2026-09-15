{
  config,
  inputs,
  mkVhost,
  ...
}:
let
  vhosts = {
    "tv.joona.codes" = {
      port = 8096; # jellyfin
      # Buffering a transcode to disk before forwarding it adds seek latency,
      # and the default body size rejects artwork and subtitle uploads.
      extraConfig = ''
        proxy_buffering off;
        client_max_body_size 20M;
      '';
    };
    "books.joona.codes" = {
      port = 9292; # audiobookshelf
      extraConfig = "client_max_body_size 2G;"; # uploads are whole books
    };
    # qui runs on the host and proxies qbittorrent inside the namespace.
    "qbt.joona.codes".port = 5252;
    "prowlarr.joona.codes".port = 9696;
    "sonarr.joona.codes".port = 8989;
    "radarr.joona.codes".port = 7878;
    "bazarr.joona.codes".port = 6767;
    "seerr.joona.codes".port = 5055;
    "shelfmark.joona.codes".port = 8084;
  };
in
{
  imports = [ inputs.nixarr.nixosModules.default ];

  # A wg-quick config from account.protonvpn.com, generated against a P2P
  # server with NAT-PMP enabled. Read straight off disk, not an EnvironmentFile.
  age.secrets.protonvpn.file = ../../../secrets/host/protonvpn.age;

  nixarr = {
    enable = true;
    mediaUsers = [ "joona" ];

    # nixarr's defaults. Everything is on the one LUKS root anyway, and its
    # layout keeps downloads and library on the same filesystem so the arrs
    # hardlink instead of copying, which is what lets a torrent keep seeding
    # after import.
    mediaDir = "/data/media";
    stateDir = "/data/.state/nixarr";

    vpn = {
      enable = true;
      wgConf = config.age.secrets.protonvpn.path;
      exposeOnLAN = false;
    };

    jellyfin.enable = true;
    audiobookshelf.enable = true;

    # Only the torrent client is confined. The indexers and the arrs stay on
    # the normal route: the tracker locks a session to the IP that created it,
    # and the home address is stable where the Proton exit address is not.
    qbittorrent = {
      enable = true;
      vpn.enable = true;
      qui.enable = true;

      privateTrackers.disableDhtPex = true;
      torrentQueueing.enable = false;
    };

    prowlarr.enable = true;
    sonarr.enable = true;
    radarr.enable = true;
    bazarr.enable = true;
    seerr.enable = true;
    shelfmark.enable = true;
  };

  services.nginx.virtualHosts = builtins.mapAttrs (
    _: args: mkVhost (args // { tailnetOnly = true; })
  ) vhosts;
}
