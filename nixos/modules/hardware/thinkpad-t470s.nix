{
  config,
  lib,
  pkgs,
  ...
}:

{
  options.anderer.hardware.thinkpad.t470s = lib.mkEnableOption "Thinkpad T470s";

  config = lib.mkIf config.anderer.hardware.thinkpad.t470s {
    anderer.hardware.thinkpad.enable = true;

    boot.initrd.availableKernelModules = [
      "nvme"
      "ehci_pci"
      "xhci_pci"
      "usb_storage"
      "sd_mod"
    ];

    networking.wireless.interfaces = [ "wlp58s0" ];
    anderer.hardware.wireless.powerSave.enable = false;

    hardware.graphics.extraPackages = with pkgs; [
      intel-media-driver
      intel-ocl
      intel-vaapi-driver
    ];

    services.fwupd.enable = true;

    anderer.os.workstation = {
      battery = true;
      internalDisplay = "eDP-1";
      displayScale = 1.0;
      ytdlVideoCodec = "vp9";
    };
  };
}
