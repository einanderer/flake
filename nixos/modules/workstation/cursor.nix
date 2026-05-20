{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.anderer.os.workstation.cursor;
  inherit (lib) mkEnableOption mkIf;
in
{
  options.anderer.os.workstation.cursor = {
    enable = mkEnableOption "Cursor IDE";
  };

  config = mkIf cfg.enable {
    environment.systemPackages = [ pkgs.code-cursor ];
  };
}
