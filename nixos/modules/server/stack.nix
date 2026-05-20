{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.anderer.server.stack;
in
{
  options.anderer.server.stack = {
    enable = lib.mkEnableOption ''
      Server monitoring stack: Grafana, PostgreSQL, Prometheus exporters, nginx reverse proxy.
      Intended for VPS hosts; more hosts can enable this module with their own domain/alias.
    '';

    hostAlias = lib.mkOption {
      type = lib.types.str;
      description = "Prometheus label for this host.";
    };

    grafanaDomain = lib.mkOption {
      type = lib.types.str;
      description = "Public domain for Grafana (nginx + ACME).";
    };
  };

  config = lib.mkIf cfg.enable {
    sops.secrets = {
      admin_grafana = {
        owner = "grafana";
      };
      skey_grafana = {
        owner = "grafana";
      };
    };

    services.postgresql = {
      enable = true;
      package = pkgs.postgresql;
      ensureDatabases = [ "grafana" ];
      ensureUsers = [
        {
          name = "grafana";
          ensureDBOwnership = true;
        }
      ];
    };

    services.prometheus = {
      enable = true;
      scrapeConfigs = [
        {
          job_name = "node";
          static_configs = [
            {
              labels.alias = cfg.hostAlias;
              targets = [ "localhost:9100" ];
            }
          ];
        }
        {
          job_name = "postgres";
          static_configs = [
            {
              labels.alias = cfg.hostAlias;
              targets = [ "localhost:9187" ];
            }
          ];
        }
        {
          job_name = "nginx";
          static_configs = [
            {
              labels.alias = cfg.hostAlias;
              targets = [ "localhost:9113" ];
            }
          ];
        }
      ];
      exporters = {
        node.enable = true;
        postgres = {
          enable = true;
          runAsLocalSuperUser = true;
        };
        nginx.enable = true;
      };
    };

    services.grafana = {
      enable = true;
      settings = {
        server.domain = cfg.grafanaDomain;
        database = {
          type = "postgres";
          host = "/run/postgresql";
          user = "grafana";
        };
        security = {
          admin_user = "admin";
          admin_password = "$__file{${config.sops.secrets.admin_grafana.path}}";
          secret_key = "$__file{${config.sops.secrets.skey_grafana.path}}";
        };
        analytics.reporting_enable = false;
      };
    };

    services.nginx = {
      enable = true;
      statusPage = true;
      resolver.addresses = [ "1.1.1.1" ];
      virtualHosts.${cfg.grafanaDomain} = {
        locations."/" = {
          proxyPass = "http://localhost:3000";
          proxyWebsockets = true;
        };
        enableACME = true;
        forceSSL = true;
      };
    };
  };
}
