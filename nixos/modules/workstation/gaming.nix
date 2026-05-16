{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.anderer.workstation.gaming;
  inherit (lib)
    mkEnableOption
    mkIf
    mkMerge
    mkOption
    optionals
    types
    ;
in
{
  options.anderer.workstation.gaming = {
    enable = mkEnableOption "gaming support";

    lutris = {
      enable = mkEnableOption "Lutris" // {
        default = config.anderer.workstation.gaming.enable;
      };
    };

    heroic = {
      enable = mkEnableOption "Heroic Games Launcher" // {
        default = config.anderer.workstation.gaming.enable;
      };
    };

    wine = {
      enable = mkEnableOption "Wine";
    };

    streaming = {
      enable = mkEnableOption "Sunshine game streaming host";
    };

    remotePlay = {
      enable = mkEnableOption "Moonlight-compatible remote play client";
    };

    extraPackages = mkOption {
      type = types.listOf types.package;
      default = [ ];
      description = "Additional packages for this host's gaming setup";
    };
  };

  config = mkIf cfg.enable {
    hardware.graphics.enable32Bit = pkgs.stdenv.hostPlatform.isx86_64;

    services.pipewire.alsa.support32Bit = pkgs.stdenv.hostPlatform.isx86_64;

    programs.steam = {
      enable = true;
      remotePlay.openFirewall = true;
      localNetworkGameTransfers.openFirewall = true;
      gamescopeSession.enable = true;
    };

    programs.gamescope.enable = true;

    programs.appimage = {
      enable = true;
      binfmt = true;
    };

    environment.systemPackages =
      optionals cfg.lutris.enable [ pkgs.lutris-free ]
      ++ optionals cfg.heroic.enable [ pkgs.heroic ]
      ++ optionals cfg.wine.enable [ pkgs.wine ]
      ++ optionals cfg.remotePlay.enable [ pkgs.moonlight-qt ]
      ++ cfg.extraPackages;

    services.sunshine = mkIf cfg.streaming.enable {
      enable = true;
      autoStart = true;
      capSysAdmin = true;
      openFirewall = true;
    };

    networking.firewall = mkMerge [
      (mkIf cfg.streaming.enable {
        allowedTCPPorts = [
          47984
          47989
          47990
          48010
        ];
        allowedUDPPortRanges = [
          {
            from = 47998;
            to = 48000;
          }
          {
            from = 8000;
            to = 8010;
          }
        ];
      })
    ];
  };
}
