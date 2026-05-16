{
  lib,
  config,
  ...
}:
{
  options.anderer.workstation = {
    xorg-settings = lib.mkOption {
      type = lib.types.bool;
      default = config.anderer.workstation.wayland;
    };
  };

  config = lib.mkIf config.anderer.workstation.xorg-settings {
    stylix.targets.xresources.enable = true;
    xresources.properties = {
      "Xft.hinting" = "1";
      "Xft.hintstyle" = "hintslight";
      "Xft.antialias" = "1";
      "Xft.rgba" = "rgb";
    };
  };
}
