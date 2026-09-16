{
  config,
  lib,
  email,
  ...
}:
let
  cfg = config.joona.services.web;

  # Creates a virtual host that always has access via the tailnet, and
  # public access is `public` is set.
  toVirtualHost =
    vhost:
    let
      backend = "http://${vhost.host}:${toString vhost.port}";

      gate = lib.optionalString (!vhost.public) ''
        ${lib.concatMapStringsSep "\n" (cidr: "allow ${cidr};") config.joona.tailnet.cidrs}
        deny all;
      '';
    in
    {
      forceSSL = true;
      enableACME = true;
      # Null here lets security.acme.defaults.dnsProvider apply
      acmeRoot = null;
      locations = {
        "/" = {
          proxyPass = backend;
          proxyWebsockets = true;
          extraConfig = gate + vhost.extraConfig;
        };
      }
      # Rate limiting to login paths
      // lib.listToAttrs (
        map (
          path:
          lib.nameValuePair "= ${path}" {
            proxyPass = backend;
            extraConfig = gate + "limit_req zone=login burst=10 nodelay;";
          }
        ) vhost.loginPaths
      );
    };
in
{
  options.joona.services.web.enable = lib.mkEnableOption "nginx and ACME";

  options.joona.vhosts = lib.mkOption {
    default = { };
    description = ''
      Reverse proxied services, keyed by hostname. Each gets a certificate over
      DNS-01 and is reachable from the tailnet only unless it sets `public`.
    '';
    type = lib.types.attrsOf (
      lib.types.submodule {
        options = {
          port = lib.mkOption {
            type = lib.types.port;
            description = "Port the backend listens on.";
          };

          host = lib.mkOption {
            type = lib.types.str;
            default = "127.0.0.1";
            description = ''
              For the one kind of backend that is not on loopback: a service
              confined to a network namespace, reached over the veth pair rather
              than through it.
            '';
          };

          public = lib.mkOption {
            type = lib.types.bool;
            default = false;
            description = "Reachable from the internet rather than the tailnet only.";
          };

          loginPaths = lib.mkOption {
            type = lib.types.listOf lib.types.str;
            default = [ ];
            example = [ "/login" ];
            description = ''
              Endpoints that take a password. Each gets a rate limit, and the
              jail below bans whoever keeps tripping it.
            '';
          };

          extraConfig = lib.mkOption {
            type = lib.types.lines;
            default = "";
            description = "Appended to the vhost's own location block.";
          };
        };
      }
    );
  };

  config = lib.mkIf cfg.enable {
    age.secrets.acme.file = ../../../secrets/host/acme.age;

    # Every certificate is issued over DNS-01, so nothing has to reach port 80
    # from the internet and tailnet-only hosts can still have a public cert.
    security.acme = {
      acceptTerms = true;
      defaults = {
        inherit email;
        dnsProvider = "cloudflare";
        environmentFile = config.age.secrets.acme.path;
        dnsResolver = "1.1.1.1:53";
      };
    };

    services.nginx = {
      enable = true;
      recommendedGzipSettings = true;
      recommendedOptimisation = true;
      recommendedProxySettings = true;
      recommendedTlsSettings = true;

      virtualHosts = builtins.mapAttrs (_: toVirtualHost) config.joona.vhosts // {
        default = {
          default = true;
          rejectSSL = true;
          locations."/".return = "444";
        };
      };

      # Keyed on the /64 for v6, or one allocation would be 2^64 keys. Lazily
      # evaluated, so only the login locations pay for the regex.
      appendHttpConfig = ''
        map $remote_addr $login_key {
          default                                  $binary_remote_addr;
          "~(?<prefix>^[^:]+:[^:]+:[^:]+:[^:]+):"  $prefix;
        }
        limit_req_zone $login_key zone=login:1m rate=20r/m;
      '';
    };

    services.fail2ban.jails.nginx-limit-req.settings = {
      filter = "nginx-limit-req";
      journalmatch = "_SYSTEMD_UNIT=nginx.service";
      maxretry = 20;
      findtime = 600;
      bantime = "1h";
    };

    networking.firewall.allowedTCPPorts = [
      80
      443
    ];
  };
}
