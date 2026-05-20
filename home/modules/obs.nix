{
  config,
  osConfig,
  pkgs,
  lib,
  ...
}:
{
  options.anderer.home.workstation.obs = lib.mkOption {
    type = lib.types.bool;
    default = osConfig.anderer.os.workstation.enable && pkgs.stdenv.hostPlatform.isx86_64;
  };

  config = lib.mkIf config.anderer.home.workstation.obs {
    home.packages = [ pkgs.obs-cmd ];
    programs.obs-studio = {
      enable = true;
      package = pkgs.obs-studio;
      plugins = with pkgs.obs-studio-plugins; [
        obs-multi-rtmp
        obs-gstreamer
        wlrobs
        obs-pipewire-audio-capture
        obs-move-transition
        obs-tuna
        obs-text-pthread
        waveform
        obs-vintage-filter
        obs-shaderfilter
        obs-composite-blur
        obs-source-record
        obs-source-clone
      ];
    };
  };
}
