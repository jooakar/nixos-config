{ pkgs, ... }:
{
  environment.systemPackages = with pkgs; [
    curl
    wget
    rsync
    htop
    lsof
    dnsutils
    pciutils
    nmap
    tcpdump
  ];
}
