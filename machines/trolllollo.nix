{
  config,
  ...
}:

{
  system.stateVersion = "25.05";

  time.timeZone = "Europe/Berlin";

  fileSystems."/" = {
    device = "/dev/disk/by-uuid/5ad8e402-7054-42dc-b1c4-3f31ffe0e336";
    fsType = "ext4";
  };

  boot.initrd.luks.devices."luks-2a273f06-53c0-4e12-9f7b-6510b4900f51" = {
    device = "/dev/disk/by-uuid/2a273f06-53c0-4e12-9f7b-6510b4900f51";
    allowDiscards = true;
  };

  fileSystems."/boot" = {
    device = "/dev/disk/by-uuid/8A36-7EF2";
    fsType = "vfat";
    options = [
      "fmask=0022"
      "dmask=0022"
    ];
  };

  boot.loader.systemd-boot.enable = true;

  sops = {
    secrets = {
      ttvpn-private = {
        owner = "systemd-network";
      };
      ttvpn-psk = {
        owner = "systemd-network";
      };
    };
  };

  networking = {
    hostName = "trolllollo";
    wireguard.interfaces = {
      ttvpn = {
        ips = [ "10.111.101.60/32" ];
        allowedIPsAsRoutes = true;
        peers = [
          {
            #allowedIPs = [ "0.0.0.0/0" ];
            allowedIPs = [
              "10.111.101.0/24"
              "192.168.100.0/24"
              "10.0.0.0/24"
            ];
            endpoint = "tentacle.tagesthe.men:52342";
            publicKey = "wc70z49Afc94vFGvSQUioZbslgBHtFLWxckl9RMzuwc=";
            presharedKeyFile = config.sops.secrets.ttvpn-psk.path;
            persistentKeepalive = 25;
          }
        ];
        privateKeyFile = config.sops.secrets.ttvpn-private.path;
        mtu = 1300;
      };
    };
    firewall.allowedUDPPorts = [ 52342 ];
  };

  bpletza.hardware.thinkpad.t470s = true;
  bpletza.secureboot = false;
  bpletza.workstation = {
    enable = true;
    gaming = true;
    libvirt = true;
  };

}
