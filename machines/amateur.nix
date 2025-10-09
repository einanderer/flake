{
  pkgs,
  ...
}:

{
  system.stateVersion = "25.05";

  time.timeZone = "Europe/Berlin";

  hardware.firmware = [
    pkgs.linux-firmware
    pkgs.alsa-firmware
  ];

  boot.initrd.availableKernelModules = [
    "nvme"
    "xhci_pci"
    "ahci"
    "usbhid"
    "usb_storage"
    "sd_mod"
  ];
  boot.kernelModules = [ "kvm-amd" ];

  fileSystems."/" = {
    device = "/dev/disk/by-uuid/91848f23-e272-42ff-8120-5d052957a589";
    fsType = "ext4";
  };

  boot.initrd.luks.devices."luks-483d78a4-d8f1-431f-a4ae-41bee539ad16" = {
    device = "/dev/disk/by-uuid/483d78a4-d8f1-431f-a4ae-41bee539ad16";
  };

  fileSystems."/boot" = {
    device = "/dev/disk/by-uuid/BAD7-EBB1";
    fsType = "vfat";
    options = [
      "fmask=0077"
      "dmask=0077"
    ];
  };

  fileSystems."/mnt/SSDA" = {
    device = "/dev/disk/by-uuid/02E4AAD8E4AACD6B";
    fsType = "ntfs-3g";
    options = [
      "rw"
      "uid=1000"
    ];
  };

  fileSystems."/mnt/SSDB" = {
    device = "/dev/disk/by-uuid/748A75CD8A758BFC";
    fsType = "ntfs-3g";
    options = [
      "rw"
      "uid=1000"
    ];
  };

  fileSystems."/mnt/NVME1" = {
    device = "/dev/disk/by-uuid/CC78D29878D2811E";
    fsType = "ntfs-3g";
    options = [
      "rw"
      "uid=1000"
    ];
  };

  boot.loader.systemd-boot.enable = true;

  networking.hostName = "amateur"; # Define your hostname.

  programs.coolercontrol.enable = true;
  services.lact.enable = true;

  home-manager.sharedModules = [
    {
      programs.waybar.settings.mainBar.temperature = {
        hwmon-path-abs = "/sys/devices/pci0000:00/0000:00:18.3/hwmon/hwmon5";
        input-filename = "temp1_input";
        warning-threshold = 80;
        critical-threshold = 90;
      };
    }
  ];

  bpletza.hardware = {
    cpu.amd = true;
    gpu.amd = true;
  };
  bpletza.secureboot = false;
  bpletza.workstation = {
    enable = true;
    gaming = true;
    libvirt = true;
    ai = true;
    ytdlVideoCodec = "av01";
    ytdlMaxRes = 2160;
  };
}
