{
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

  sops.secrets = {
    ttvpn_s-private.owner = "systemd-network";
    ttvpn_router-psk.owner = "systemd-network";
    ttvpn_trolllollo-psk.owner = "systemd-network";
    ttvpn_iphone12-psk.owner = "systemd-network";
    ttvpn_spare-psk.owner = "systemd-network";
  };

  networking.hostName = "tentacle";

  anderer.network.tentacleEdge.enable = true;

  anderer.server.stack = {
    enable = true;
    hostAlias = "tentacle";
    grafanaDomain = "meine.tagesthe.men";
  };

  anderer.network.ttvpn = {
    enable = true;
    privateKeyFile = config.sops.secrets.ttvpn_s-private.path;
    hub = {
      listenPort = 52342;
      addresses = [
        "10.111.101.1/32"
        "fd72:db04:ef1a:e953::1/128"
      ];
      peers = [
        {
          name = "GL-AX1800";
          allowedIPs = [
            "10.111.101.0/24"
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
}
