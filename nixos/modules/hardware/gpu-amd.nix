{
  config,
  lib,
  pkgs,
  ...
}:

{
  options.anderer.hardware.gpu.amd = lib.mkEnableOption "AMD GPUs";

  config = lib.mkIf config.anderer.hardware.gpu.amd {

    boot.initrd.kernelModules = [ "amdgpu" ];

    hardware.amdgpu = {
      opencl.enable = false;
      initrd.enable = true;
      overdrive = {
        enable = true;
        ppfeaturemask = "0xffffffff";
      };
    };

    environment.systemPackages = [
      pkgs.radeontop
    ];
  };
}
