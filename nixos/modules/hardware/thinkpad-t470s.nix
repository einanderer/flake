{
  config,
  lib,
  pkgs,
  ...
}:

{
  options.bpletza.hardware.thinkpad.t470s = lib.mkEnableOption "Thinkpad T470s";

  config = lib.mkIf config.bpletza.hardware.thinkpad.t470s {

    boot = {
      initrd.availableKernelModules = [
        "nvme"
        "ehci_pci"
        "xhci_pci"
        "usb_storage"
        "sd_mod"
      ];
      extraModprobeConfig = ''
        options thinkpad_acpi experimental=1 fan_control=1
      '';
    };

    networking.wireless = {
      enable = true;
      interfaces = [ "wlp58s0" ];
    };

    bpletza.hardware.wireless.powerSave.enable = false;

    hardware = {
      firmware = with pkgs; [
        linux-firmware
        alsa-firmware
      ];
      trackpoint = {
        enable = true;
      };
      wirelessRegulatoryDatabase = true;
      cpu.intel.updateMicrocode = true;
      graphics.extraPackages = with pkgs; [
        intel-media-driver
        intel-ocl
        intel-vaapi-driver
      ];
    };

    services.fwupd.enable = true;

    # CPU Temp spezifisch fuers Device fuer die Waybar
    #home-manager.sharedModules = [
    #  {
    #    programs.waybar.settings.mainBar.temperature = {
    #      hwmon-path-abs = "/sys/devices/pci0000:00/0000:00:18.3/hwmon";
    #      input-filename = "temp1_input";
    #      warning-threshold = 80;
    #      critical-threshold = 90;
    #    };
    #  }
    #];

    bpletza.workstation = {
      battery = true;
      internalDisplay = "eDP-1";
      displayScale = 1.0;
      #waybar.wiredInterface = "enp0s31f6";
      ytdlVideoCodec = "vp9";
    };
  };
}
