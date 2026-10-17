{
  config,
  lib,
  ...
}:
let
  inherit (lib)
    types
    mkEnableOption
    mkOption
    ;
in
{
  options.anderer.os.workstation = {
    enable = mkEnableOption "${config.anderer.home.user} workstation";
    battery = mkEnableOption "machine has battery";
    libvirt = mkOption {
      type = types.bool;
      description = "libvirtd";
    };

    waybar.wiredInterface = mkOption {
      type = types.str;
      default = "enp*";
      description = "Interface name or wildcard for wired interface";
    };

    ytdlVideoCodec = mkOption {
      type = types.str;
      default = "av01";
      description = "youtube-dl video codec";
    };

    ytdlMaxRes = mkOption {
      type = types.int;
      default = 1080;
      description = "youtube-dl maximum resolution";
    };

    ai = mkEnableOption "AI";

    internalDisplay = mkOption {
      type = types.nullOr types.str;
      default = null;
      description = ''
        Name of the internal display (e.g. eDP-1, LVDS-1).
      '';
    };

    displayScale = mkOption {
      type = types.nullOr types.float;
      default = null;
      description = "Set scale of internal display";
    };
  };
}
