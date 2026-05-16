{
  pkgs,
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
  #boot.kernelPackages = lib.mkForce pkgs.linuxPackages_cachyos;

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

  #chaotic.hdr.enable = true;

  #services.pipewire.extraConfig.pipewire."99-line-in-loopback" = {
  #  "context.modules" = [
  #    {
  #      name = "libpipewire-module-loopback";
  #      args = {
  #        "node.description" = "Line-In Monitor"; # Name im Audiomixer
  #        "capture.props" = {
  #          "node.name" = "line_in_capture";
  #          "target.object" = "alsa_input.pci-0000_10_00.4.analog-stereo"; # Deinen Device-Namen hier einsetzen
  #        };
  #        "playback.props" = {
  #          "node.name" = "line_in_playback";
  #          "media.class" = "Audio/Sink"; # Erstellt ein virtuelles Wiedergabegerät
  #        };
  #      };
  #    }
  #  ];
  #};

  environment.systemPackages = with pkgs; [
    hardinfo2
    liquidctl
    qpwgraph
    fluffychat
    element-desktop
    legcord
    kdePackages.qtsvg
    kdePackages.dolphin
  ];

  anderer.hardware = {
    cpu.amd = true;
    gpu.amd = true;
  };
  anderer.secureboot = false;
  anderer.workstation = {
    enable = true;
    libvirt = false;
    ai = true;
    ytdlVideoCodec = "av01";
    ytdlMaxRes = 2160;
    gaming = {
      enable = true;
      wine.enable = true;
      streaming.enable = true;
      extraPackages = with pkgs; [
        dosbox-x
        ryubing
      ];
    };
  };
}
