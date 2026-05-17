{
  config,
  lib,
  ...
}:
let
  cfg = config.anderer.network.serverUplink;
in
{
  options.anderer.network.serverUplink = {
    enable = lib.mkEnableOption ''
      Minimal DHCP uplink for the inactive QEMU server host.
    '';
  };

  config = lib.mkIf cfg.enable {
    networking.useDHCP = false;

    systemd.network.networks."10-uplink" = {
      matchConfig.Name = [
        "eth0"
        "enp*"
        "ens*"
      ];
      networkConfig.DHCP = true;
      linkConfig.RequiredFamilyForOnline = "any";
    };
  };
}
