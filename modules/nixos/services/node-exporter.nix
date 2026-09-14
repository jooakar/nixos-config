{ ... }:
{
  # 9100 is never in allowedTCPPorts, so this is only reachable on loopback and
  # over the tailnet, which is the interface the vps scrapes other nodes on.
  services.prometheus.exporters.node = {
    enable = true;
    listenAddress = "0.0.0.0";
  };
}
