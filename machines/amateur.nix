{
  pkgs,
  lib,
  ...
}:

{
  ##temoporär damits baut
  #nixpkgs.config.permittedInsecurePackages = [
  #  "electron-36.9.5"
  #];

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
  boot.kernelParams = [ "acpi_enforce_resources=lax" ];
  boot.kernelModules = [
    "kvm-amd"
    "coretemp"
    "it87"
  ];
  #boot.extraModprobeConfig = ''
  #  options it87 force_id=0x8689
  #  options it87 force_id=0x8795
  #'';

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
  boot.kernelPackages = lib.mkForce pkgs.linuxPackages_cachyos;

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

  chaotic.hdr.enable = true;

  services.sunshine = {
    enable = true;
    autoStart = true;
    capSysAdmin = true;
    openFirewall = true;
  };
  networking.firewall = {
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
  };

  environment.systemPackages = with pkgs; [
    # Benchmark
    hardinfo2
    geekbench
    unigine-valley
    unigine-heaven
    unigine-tropics
    unigine-sanctuary
    unigine-superposition
    # Gaming
    heroic
    #protonup-qt
    # Tools
    liquidctl
    qpwgraph
    fluffychat
    legcord
    kdePackages.qtsvg
    kdePackages.dolphin
    rustdesk
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
