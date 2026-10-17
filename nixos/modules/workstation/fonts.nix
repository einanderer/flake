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
    fonts = {
      fontconfig = {
        enable = true;
        defaultFonts = {
          emoji = [ "Noto Color Emoji" ];
          monospace = [
            "0xProto"
            "Noto Color Emoji"
            "Font Awesome 6 Free"
            "Font Awesome 5 Free"
          ];
          sansSerif = [
            "Recursive Sans Casual Static"
            "Noto Color Emoji"
            "Font Awesome 6 Free"
            "Font Awesome 5 Free"
          ];
          serif = [
            "Recursive Sans Casual Static"
            "Noto Color Emoji"
            "Font Awesome 6 Free"
            "Font Awesome 5 Free"
          ];
        };
        subpixel = {
          rgba = mkDefault "rgb";
        };
      };
      enableDefaultPackages = true;
      packages = with pkgs; [
        font-awesome_5
        font-awesome_6
        b612
        ubuntu-classic
        noto-fonts
        fira-code
        fira-mono
        fira-sans
        nerd-fonts.symbols-only
        inter
        commit-mono
        departure-mono
      ];
    };
  };
}
