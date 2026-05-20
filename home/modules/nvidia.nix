{
  lib,
  config,
  osConfig,
  ...
}:
{
  options.anderer.home.workstation.nvidia = lib.mkOption {
    type = lib.types.bool;
    default =
      config.anderer.home.workstation.wayland && (osConfig.anderer.os.workstation.nvidia or false);
  };

  config = lib.mkIf config.anderer.home.workstation.nvidia {
    wayland.windowManager.sway = {
      extraOptions = [ "--unsupported-gpu" ];
    };

    home.sessionVariables = {
      WLR_RENDERER = "vulkan";
      # OpenGL Variables
      GBM_BACKEND = "nvidia-drm";
      __GLX_VENDOR_LIBRARY_NAME = "nvidia";
      # libva stuff
      MOZ_DISABLE_RDD_SANDBOX = 1;
      NVD_BACKEND = "direct";
      LIBVA_DRIVER_NAME = "nvidia";
    };
  };
}
