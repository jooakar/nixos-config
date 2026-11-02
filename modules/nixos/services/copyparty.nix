{
  config,
  inputs,
  lib,
  ...
}:
let
  cfg = config.joona.services.copyparty;

  port = 3923;
in
{
  imports = [ inputs.copyparty.nixosModules.default ];

  options.joona.services.copyparty.enable =
    lib.mkEnableOption "copyparty, for moving files between devices and sharing links";

  config = lib.mkIf cfg.enable {
    age.secrets.copyparty = {
      file = ../../../secrets/host/copyparty.age;
      owner = "copyparty";
    };

    services.copyparty = {
      enable = true;
      settings = {
        i = "127.0.0.1";
        p = port;
        no-reload = true;
        hist = "/var/cache/copyparty";

        # nginx sets X-Real-IP, which the login bans need to see
        xff-hdr = "x-real-ip";
        xff-src = "127.0.0.1";
        rproxy = 1;

        shr = "/share";
        # Expired shares are only cleaned up with the uploads database on
        e2d = true;
      };
      accounts.joona.passwordFile = config.age.secrets.copyparty.path;
      volumes."/" = {
        path = "/data/files";
        access.A = "joona";
      };
    };

    joona.services.web.enable = true;
    joona.vhosts."files.joona.codes" = {
      inherit port;
      # Share links have to open for people outside the tailnet
      public = true;
      extraConfig = ''
        client_max_body_size 0;
        proxy_request_buffering off;
        proxy_buffering off;
      '';
    };
  };
}
