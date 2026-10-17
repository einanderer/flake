{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.anderer.os.workstation;
  inherit (lib) mkIf mkDefault;
in
{
  config = mkIf cfg.enable {
    hardware.bluetooth = {
      enable = mkDefault true;
      powerOnBoot = mkDefault true;
      settings = {
        General = {
          AutoConnect = true;
          MultiProfile = "multiple";
          Experimental = true;
          KernelExperimental = true;
        };
      };
    };

    environment.systemPackages = lib.optional config.hardware.bluetooth.enable pkgs.bluetuith;

    systemd.user.services.mpris-proxy.wantedBy = lib.mkIf config.hardware.bluetooth.enable [
      "graphical-session.target"
    ];

    services.uxplay.enable = true;
  };
}
