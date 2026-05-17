{
  pkgs,
  modulesPath,
  config,
  ...
}:

{
  imports = [
    (modulesPath + "/profiles/qemu-guest.nix")
  ];

  system.stateVersion = "25.05";

  boot.initrd.availableKernelModules = [
    "ata_piix"
    "virtio_pci"
    "xhci_pci"
    "sd_mod"
    "sr_mod"
  ];
  boot.loader.grub.device = "/dev/sda";

  fileSystems."/" = {
    device = "/dev/disk/by-uuid/f98f14b5-83bc-4f62-98e2-7257e6c297ab";
    fsType = "ext4";
  };

  swapDevices = [ { device = "/dev/disk/by-uuid/841d2a95-6f5d-491e-8b0c-a198041dd175"; } ];

  sops = {
    secrets = {
      ttvpn_s-private = {
        owner = "systemd-network";
      };
      ttvpn_router-psk = {
        owner = "systemd-network";
      };

      ttvpn_trolllollo-psk = {
        owner = "systemd-network";
      };

      ttvpn_iphone12-psk = {
        owner = "systemd-network";
      };

      ttvpn_spare-psk = {
        owner = "systemd-network";
      };

      admin_grafana = {
        owner = "grafana";
      };

      skey_grafana = {
        owner = "grafana";
      };
    };
  };

  networking.hostName = "tentacle";

  anderer.network.tentacleEdge.enable = true;

  anderer.network.ttvpn = {
    enable = true;
    privateKeyFile = config.sops.secrets.ttvpn_s-private.path;
    hub = {
      listenPort = 52342;
      addresses = [
        "10.111.101.1/24"
        "fd72:db04:ef1a:e953::1/128"
      ];
      peers = [
        {
          name = "GL-AX1800";
          allowedIPs = [
            "10.111.101.10/32"
            "10.0.0.0/24"
            "fd72:db04:ef1a::/48"
          ];
          publicKey = "D6v/2Nx26tZ/hQ50gRw4HgWileDE+k1mjum+rrWC+BI=";
          presharedKeyFile = config.sops.secrets.ttvpn_router-psk.path;
        }
        {
          name = "WSL2-spare";
          allowedIPs = [
            "10.111.101.50/32"
            "fd72:db04:ef1a:e953::51/128"
          ];
          publicKey = "lc3jKA+legkJxN831g2lwKd9FwshShbNyg+R0RH++yo=";
          presharedKeyFile = config.sops.secrets.ttvpn_spare-psk.path;
        }
        {
          name = "trolllollo";
          allowedIPs = [
            "10.111.101.60/32"
            "fd72:db04:ef1a:e953::60/128"
          ];
          publicKey = "RdH7Is025kgKVpwLZpQJEGS8J01dM1cNJNvCbHHLJCc=";
          presharedKeyFile = config.sops.secrets.ttvpn_trolllollo-psk.path;
        }
        {
          name = "iPhone12";
          allowedIPs = [
            "10.111.101.80/32"
            "fd72:db04:ef1a:e953::80/128"
          ];
          publicKey = "+fmXEzXg9b8eYeTs2FaH2AZnrXYMLxKdtKSTszIZF0E=";
          presharedKeyFile = config.sops.secrets.ttvpn_iphone12-psk.path;
        }
      ];
    };
  };

  services.ndppd = {
    enable = true;
    proxies.ens3.rules."2a01:4f8:c2c:6a6f::1/64" = { };
  };

  services.postgresql = {
    enable = true;
    package = pkgs.postgresql;
    ensureDatabases = [
      "grafana"
    ];
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
            labels.alias = "tentacle";
            targets = [ "localhost:9100" ];
          }
        ];
      }
      {
        job_name = "postgres";
        static_configs = [
          {
            labels.alias = "tentacle";
            targets = [ "localhost:9187" ];
          }
        ];
      }
      {
        job_name = "nginx";
        static_configs = [
          {
            labels.alias = "tentacle";
            targets = [ "localhost:9113" ];
          }
        ];
      }
      # {
      #   job_name = "ohmgraphite";
      #   scrape_interval = "5s";
      #   static_configs = [
      #     { targets = [ "10.0.0.50:4445" ]; }
      #   ];
      # }
    ];
    exporters = {
      node = {
        enable = true;
        #enabledCollectors = [ "systemd" "logind" ];
      };
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
      server.domain = "meine.tagesthe.men";
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

  #services.rustdesk-server = {
  #  enable = true;
  #  openFirewall = true;
  #  signal.relayHosts = [ "tentacle.tagesthe.men" ];
  #};

  services.nginx = {
    enable = true;
    statusPage = true;
    resolver.addresses = [ "1.1.1.1" ];
    virtualHosts = {
      #"tagesthe.men" = {
      #  locations."/".root = static/www/tagesthemen;
      #  enableACME = true;
      #  forceSSL = true;
      #  default = true; # kann nur bei einen vHost verwendet werden!
      #  serverAliases = [
      #    "tentacle.tagesthe.men"
      #  ];
      #};
      # Grafana
      "meine.tagesthe.men" = {
        locations."/" = {
          proxyPass = "http://localhost:3000"; # Grafana on Tentacle
          proxyWebsockets = true;
        };
        enableACME = true;
        forceSSL = true;
      };
      # RustDesk
      # "geheime.tagesthe.men" = {
      #   locations."/" = {
      #     proxyPass = "http://localhost:6000";
      #     proxyWebsockets = true;
      #   };
      #   enableACME = true;
      #   forceSSL = true;
      # };
      # frei für service
      #"andere.tagesthe.men" = {
      #  locations."/" = {
      #    proxyPass = "http://localhost:8000";
      #    proxyWebsockets = true;
      #  };
      #  enableACME = true;
      #  forceSSL = true;
      #};
      # frei für service
      #"allgemeine.tagesthe.men" = {
      #  locations."/" = {
      #    proxyPass = "http://localhost:8080";
      #    proxyWebsockets = true;
      #  };
      #  enableACME = true;
      #  forceSSL = true;
      #};
      # frei für service
      # "feine.tagesthe.men" = {
      #   listenAddresses = [
      #     "10.111.101.1"
      #     "[fd72:db04:ef1a:e953::1]"
      #   ];
      #   locations."/" = {
      #     proxyPass = "http://localhost:19809";
      #   };
      #   enableACME = true;
      #   forceSSL = true;
      # };
    };
  };
}
