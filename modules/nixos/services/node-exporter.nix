{ config, lib, ... }:
let
  cfg = config.joona.services.node-exporter;
in
{
  options.joona.services.node-exporter.enable = lib.mkEnableOption "the Prometheus node exporter";

  config = lib.mkIf cfg.enable {
    # 9100 is never in allowedTCPPorts, so this is only reachable on loopback and
    # over the tailnet, which is the interface the vps scrapes other nodes on.
    services.prometheus.exporters.node = {
      enable = true;
      listenAddress = "0.0.0.0";
    };
  };
}
