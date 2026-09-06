{
  hostname,
  username,
  ...
}:
let
  # k3s defaults. postgres.nix opens itself to the pod range.
  podCidr = "10.42.0.0/16";

  # The GitOps repo Argo CD tracks. Everything in the cluster comes from here.
  gitopsRepo = "https://github.com/jooakar/infra.git";

  # App-of-apps root. Rendered by the Helm release itself (values.extraObjects)
  # so it lands after the Argo CD CRDs exist.
  rootApplication = {
    apiVersion = "argoproj.io/v1alpha1";
    kind = "Application";
    metadata = {
      name = "root";
      namespace = "argocd";
    };
    spec = {
      project = "default";
      source = {
        repoURL = gitopsRepo;
        targetRevision = "main";
        path = "clusters/${hostname}";
      };
      destination = {
        server = "https://kubernetes.default.svc";
        namespace = "argocd";
      };
      syncPolicy = {
        automated = {
          prune = true;
          selfHeal = true;
        };
        syncOptions = [ "CreateNamespace=true" ];
      };
    };
  };
in
{
  _module.args.k3sPodCidr = podCidr;

  services.k3s = {
    enable = true;
    role = "server";
    # Ingress is cluster content, so it comes from git rather than from k3s.
    disable = [ "traefik" ];
    extraFlags = [
      "--write-kubeconfig-mode=0640"
      "--write-kubeconfig-group=k3s"
      # Add the tailnet MagicDNS name here once the tailnet is known, otherwise
      # kubectl from outside the box hits a certificate mismatch.
      "--tls-san=${hostname}"
    ];

    autoDeployCharts.argo-cd = {
      name = "argo-cd";
      repo = "https://argoproj.github.io/argo-helm";
      version = "10.8.1";
      hash = "sha256-f3Hlr16sDrc715+vb8pgpkR0DuR3PRf1IleG6tJlsGQ=";
      targetNamespace = "argocd";
      createNamespace = true;
      values = {
        # TLS is terminated by the ingress that Argo CD itself installs.
        configs.params."server.insecure" = true;
        dex.enabled = false;
        notifications.enabled = false;
        extraObjects = [ rootApplication ];
      };
    };
  };

  users.groups.k3s = { };
  users.users.${username}.extraGroups = [ "k3s" ];
  environment.variables.KUBECONFIG = "/etc/rancher/k3s/k3s.yaml";

  # Pod traffic is forwarded and pods reach host services over cni0. The API
  # server stays off the public interface; reach it over tailscale.
  networking.firewall = {
    # ingress-nginx is exposed through klipper-lb, which binds these on the node.
    allowedTCPPorts = [
      80
      443
    ];
    trustedInterfaces = [
      "cni0"
      "flannel.1"
    ];
    checkReversePath = "loose";
  };
}
