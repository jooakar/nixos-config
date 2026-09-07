{
  config,
  pkgs,
  flakeRoot,
  ...
}:
{
  age.secrets.cloudflare-dns.file = flakeRoot + "/secrets/cloudflare-dns.age";

  systemd.services.cluster-secrets = {
    description = "Publish host secrets into the cluster";
    after = [ "k3s.service" ];
    requires = [ "k3s.service" ];
    wantedBy = [ "multi-user.target" ];
    path = [ pkgs.kubectl ];
    environment.KUBECONFIG = "/etc/rancher/k3s/k3s.yaml";
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      Restart = "on-failure";
      RestartSec = "10s";
    };
    script = ''
      kubectl create namespace cert-manager --dry-run=client -o yaml | kubectl apply -f -
      kubectl create secret generic cloudflare-api-token \
        --namespace cert-manager \
        --from-file=api-token=${config.age.secrets.cloudflare-dns.path} \
        --dry-run=client -o yaml | kubectl apply -f -
    '';
  };
}
