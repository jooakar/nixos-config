{
  config,
  mkVhost,
  ...
}:
let
  grafanaPort = 3001; # 3000 belongs to the hundred container
  lokiPort = 3100;
  prometheusPort = 9090;

  lokiPush = "http://127.0.0.1:${toString lokiPort}/loki/api/v1/push";
  retentionDays = 30;

  # Everything but nginx stays on loopback
  scrape = job: port: {
    job_name = job;
    static_configs = [ { targets = [ "127.0.0.1:${toString port}" ]; } ];
  };
in
{
  age.secrets.grafana.file = ../../secrets/host/grafana.age;

  services.prometheus = {
    enable = true;
    listenAddress = "127.0.0.1";
    port = prometheusPort;
    retentionTime = "15d";
    scrapeConfigs = [
      (scrape "prometheus" prometheusPort)
      (scrape "node" config.services.prometheus.exporters.node.port)
      (scrape "postgres" config.services.prometheus.exporters.postgres.port)
      (scrape "loki" lokiPort)
    ];

    exporters.node = {
      enable = true;
      listenAddress = "127.0.0.1";
    };
    exporters.postgres = {
      enable = true;
      listenAddress = "127.0.0.1";
      runAsLocalSuperUser = true;
    };
  };

  # Single process, single replica, local disk. The distributed modes have
  # nothing to distribute across on one node.
  services.loki = {
    enable = true;
    configuration = {
      auth_enabled = false;
      server = {
        http_listen_address = "127.0.0.1";
        http_listen_port = lokiPort;
        grpc_listen_address = "127.0.0.1";
      };
      common = {
        path_prefix = "/var/lib/loki";
        replication_factor = 1;
        ring.kvstore.store = "inmemory";
        storage.filesystem = {
          chunks_directory = "/var/lib/loki/chunks";
          rules_directory = "/var/lib/loki/rules";
        };
      };
      schema_config.configs = [
        {
          from = "2024-04-01";
          store = "tsdb";
          object_store = "filesystem";
          schema = "v13";
          index = {
            prefix = "index_";
            period = "24h";
          };
        }
      ];
      limits_config.retention_period = "${toString (retentionDays * 24)}h";
      compactor = {
        working_directory = "/var/lib/loki/compactor";
        retention_enabled = true;
        delete_request_store = "filesystem";
      };
    };
  };

  # Podman writes container output to the journal, so tailing the journal
  # covers both the host units and the applications.
  services.alloy.enable = true;
  environment.etc."alloy/config.alloy".text = ''
    loki.relabel "journal" {
      forward_to = []

      rule {
        source_labels = ["__journal__systemd_unit"]
        target_label  = "unit"
      }
      rule {
        source_labels = ["__journal__hostname"]
        target_label  = "host"
      }
    }

    loki.source.journal "default" {
      forward_to    = [loki.write.default.receiver]
      relabel_rules = loki.relabel.journal.rules
      labels        = { job = "journal" }
      max_age       = "12h"
    }

    loki.write "default" {
      endpoint {
        url = "${lokiPush}"
      }
    }
  '';

  services.grafana = {
    enable = true;
    settings = {
      server = {
        http_addr = "127.0.0.1";
        http_port = grafanaPort;
        domain = "grafana.joona.codes";
        root_url = "https://grafana.joona.codes";
      };
      # Read from the environment file below, like the admin credentials.
      security.secret_key = "$__env{GF_SECURITY_SECRET_KEY}";
    };
    provision.datasources.settings.datasources = [
      {
        name = "Prometheus";
        type = "prometheus";
        uid = "prometheus";
        url = "http://127.0.0.1:${toString prometheusPort}";
        isDefault = true;
      }
      {
        name = "Loki";
        type = "loki";
        uid = "loki";
        url = "http://127.0.0.1:${toString lokiPort}";
      }
    ];
  };

  # GF_SECURITY_ADMIN_USER / GF_SECURITY_ADMIN_PASSWORD / GF_SECURITY_SECRET_KEY,
  # which Grafana reads from its own environment without any further wiring.
  systemd.services.grafana.serviceConfig.EnvironmentFile = config.age.secrets.grafana.path;

  services.nginx.virtualHosts."grafana.joona.codes" = mkVhost {
    port = grafanaPort;
    tailnetOnly = true;
  };
}
