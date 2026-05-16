{ config, lib, ... }:
{
  options.anderer.hardware.cpu.amd = lib.mkEnableOption "AMD CPUs";

  config = lib.mkIf config.anderer.hardware.cpu.amd {
    boot = {
      kernelModules = [ "kvm-amd" ];
      kernelParams = [ "amd_pstate=active" ];
    };

    hardware.cpu.amd = {
      ryzen-smu.enable = true;
      updateMicrocode = true;
    };

    services.tuned = {
      enable = true;
    };
  };
}
