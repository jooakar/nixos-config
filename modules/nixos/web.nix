{
  config,
  lib,
  email,
  ...
}:
{
  age.secrets.acme.file = ../../secrets/host/acme.age;

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
  };

  # Services define their own vhost with this; `tailnetOnly` is the whole of
  # the access control, since the tailnet address range cannot be spoofed past
  # the UpCloud firewall.
  _module.args.mkVhost =
    {
      port,
      tailnetOnly ? false,
    }:
    {
      forceSSL = true;
      enableACME = true;
      # nginx defaults acmeRoot to a webroot and then forces dnsProvider to
      # null, which would quietly downgrade every cert to HTTP-01. Null here
      # lets security.acme.defaults.dnsProvider apply.
      acmeRoot = null;
      locations."/" = {
        proxyPass = "http://127.0.0.1:${toString port}";
        proxyWebsockets = true;
        extraConfig = lib.optionalString tailnetOnly ''
          allow 100.64.0.0/10;
          deny all;
        '';
      };
    };

  networking.firewall.allowedTCPPorts = [
    80
    443
  ];
}
