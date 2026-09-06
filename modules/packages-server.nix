{ pkgs }:
with pkgs;
[
  curl
  wget
  rsync
  htop
  lsof
  dnsutils
  pciutils
  nmap
  tcpdump

  kubectl
  kubernetes-helm
  k9s
  argocd
]
