{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.anderer.os.workstation;
  inherit (lib) mkIf;
in
{
  config = mkIf cfg.enable {
    security.rtkit.enable = true;
    services.pipewire = {
      enable = true;
      alsa.enable = true;
      pulse.enable = true;
      jack.enable = true;
      wireplumber.extraConfig.bluetoothEnhancements = {
        "monitor.bluez.properties" = {
          "bluez5.enable-sbc-xq" = true;
          "bluez5.enable-msbc" = true;
          "bluez5.enable-hw-volume" = true;
        };
      };
      extraConfig = {
        pipewire."90-networking" = {
          "context.modules" = [
            {
              name = "libpipewire-module-zeroconf-discover";
              args = {
                "pulse.latency" = 500;
              };
            }
          ];
        };
        pipewire."92-low-latency" = {
          "context.properties" = {
            "default.clock.rate" = 48000;
            "default.clock.quantum" = 128;
            "default.clock.min-quantum" = 32;
            "default.clock.max-quantum" = 1024;
          };
        };
        pipewire-pulse."92-low-latency" = {
          "pulse.properties" = {
            "pulse.min.req" = "32/48000";
            "pulse.default.req" = "128/48000";
            "pulse.max.req" = "1024/48000";
            "pulse.min.quantum" = "32/48000";
            "pulse.max.quantum" = "1024/48000";
          };
          "stream.properties" = {
            "node.latency" = "32/48000";
            "resample.quality" = 8;
          };
        };
      };
    };

    environment.systemPackages = [
      pkgs.alsa-utils
      pkgs.pulsemixer
      pkgs.wiremix
    ];
  };
}
