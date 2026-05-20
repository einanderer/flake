{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.anderer.hardware.thinkpad;
in
{
  options.anderer.hardware.thinkpad = {
    enable = lib.mkEnableOption "shared ThinkPad settings (enable a model module too)";
  };

  config = lib.mkIf cfg.enable {
    boot.extraModprobeConfig = lib.mkBefore ''
      options thinkpad_acpi experimental=1 fan_control=1
    '';

    networking.wireless.enable = lib.mkDefault true;

    hardware = {
      firmware = with pkgs; [
        linux-firmware
        alsa-firmware
      ];
      trackpoint.enable = true;
      wirelessRegulatoryDatabase = true;
      cpu.intel.updateMicrocode = lib.mkDefault true;
    };
  };
}
