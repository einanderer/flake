{
  config,
  lib,
  ...
}:
let
  cfg = config.anderer.os.workstation;
  inherit (lib) mkIf;
in
{
  config = mkIf cfg.enable {
    anderer.os.workstation.libvirt = !cfg.battery;

    virtualisation.podman = {
      enable = true;
      dockerCompat = true;
      dockerSocket.enable = true;
      autoPrune = {
        enable = true;
        dates = "weekly";
      };
    };

    virtualisation.libvirtd.enable = cfg.libvirt;
  };
}
