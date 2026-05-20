{
  config,
  pkgs,
  ...
}:

{
  system.stateVersion = "25.05";

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

  sops.secrets = {
    ttvpn-private.owner = "systemd-network";
    ttvpn-psk.owner = "systemd-network";
  };

  networking.hostName = "trolllollo";

  anderer.profiles.workstation.enable = true;
  anderer.profiles.workstationLaptop.enable = true;

  anderer.network.ttvpn = {
    enable = true;
    privateKeyFile = config.sops.secrets.ttvpn-private.path;
    client = {
      addresses = [
        "10.111.101.60/32"
        "fd72:db04:ef1a:e953::60/128"
      ];
      endpoint = "tentacle.tagesthe.men:52342";
      peerPublicKey = "wc70z49Afc94vFGvSQUioZbslgBHtFLWxckl9RMzuwc=";
      presharedKeyFile = config.sops.secrets.ttvpn-psk.path;
      allowedIPs = [
        "10.111.101.0/24"
        "192.168.100.0/24"
        "10.0.0.0/24"
        "fd72:db04:ef1a::/48"
      ];
    };
  };

  environment.systemPackages = [ pkgs.unzip ];

  anderer.hardware.thinkpad.t470s = true;

  anderer.os.workstation.gaming = {
    enable = true;
    remotePlay.enable = true;
  };
}
