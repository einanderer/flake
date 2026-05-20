{
  config,
  lib,
  pkgs,
  ...
}:
{
  options.anderer.hardware.thinkpad.x230 = lib.mkEnableOption "Thinkpad X230";

  config = lib.mkIf config.anderer.hardware.thinkpad.x230 {
    anderer.hardware.thinkpad.enable = true;

    boot = {
      initrd = {
        availableKernelModules = [
          "xhci_pci"
          "ehci_pci"
          "ahci"
          "usb_storage"
          "sd_mod"
          "sdhci_pci"
        ];
        kernelModules = [ "i915" ];
      };
      kernelPackages = lib.mkForce pkgs.linuxPackages_latest;
      kernelModules = [ "kvm-intel" ];
      blacklistedKernelModules = [
        "mei_me"
        "mei"
      ];
    };

    networking.wireless.interfaces = [ "wlp2s0" ];

    hardware.graphics.extraPackages = [
      pkgs.intel-vaapi-driver
    ];

    environment.systemPackages = with pkgs; [
      intel-gpu-tools
      coreboot-utils
    ];

    services.tuned.enable = true;

    anderer.os.workstation = {
      battery = true;
      waybar.wiredInterface = "eno0";
      ytdlVideoCodec = "avc1";
      internalDisplay = "LVDS-1";
      displayScale = 1.0;
    };
  };
}
