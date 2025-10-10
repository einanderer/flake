{
  lib,
  config,
  pkgs,
  inputs,
  ...
}:
{
  imports = [
    inputs.disko.nixosModules.default
    inputs.sops-nix.nixosModules.sops
  ]
  ++ lib.filesystem.listFilesRecursive ./default;

  nixpkgs.overlays = [
    inputs.self.overlays.default
    inputs.bad_gateway.overlays.default
  ];

  nixpkgs.flake = {
    source = lib.mkDefault inputs.nixpkgs;
    setNixPath = lib.mkDefault true;
    setFlakeRegistry = lib.mkDefault true;
  };

  sops = {
    defaultSopsFile = ../../secrets + "/${config.networking.hostName}.yaml";
  };

  environment.sessionVariables = {
    # https://consoledonottrack.com/
    DO_NOT_TRACK = "1";
  };

  time.timeZone = lib.mkDefault "UTC";
  console.keyMap = "us";
  i18n = {
    defaultLocale = "en_US.UTF-8";
    extraLocales = [
      "en_US.UTF-8/UTF-8"
      "de_DE.UTF-8/UTF-8"
    ];
    extraLocaleSettings = {
      LC_ADDRESS = "de_DE.UTF-8";
      LC_IDENTIFICATION = "de_DE.UTF-8";
      LC_MEASUREMENT = "de_DE.UTF-8";
      LC_MONETARY = "de_DE.UTF-8";
      LC_NAME = "de_DE.UTF-8";
      LC_PAPER = "de_DE.UTF-8";
      LC_TELEPHONE = "de_DE.UTF-8";
      LC_TIME = "C.UTF-8";
    };
  };

  powerManagement.cpuFreqGovernor = lib.mkDefault "performance";

  boot = {
    enableContainers = false;
    tmp.useTmpfs = lib.mkDefault true;
    kernelPackages = lib.mkOverride 1001 pkgs.linuxPackages_latest;
    loader = {
      timeout = lib.mkDefault 3;
      grub.splashImage = null;
      systemd-boot.configurationLimit = 10;
    };
    kernel.sysctl = {
      # fail fast on oom
      "vm.oom_kill_allocating_task" = 1;
    };
  };

  documentation = {
    # regular manpages are enough
    doc.enable = false;
    info.enable = false;
    nixos.extraModules = [ inputs.self.nixosModules.all ];
  };

  fonts.fontconfig.enable = lib.mkDefault false;

  xdg = {
    autostart.enable = lib.mkDefault false;
    icons.enable = lib.mkDefault false;
    menus.enable = lib.mkDefault false;
    mime.enable = lib.mkDefault false;
    sounds.enable = lib.mkDefault false;
  };

  users = {
    mutableUsers = false;
    users = {
      nix-build = {
        uid = 1100;
        isNormalUser = true;
        openssh.authorizedKeys.keys = [
          "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAILlbG1MLUOzT5tS58v8yjahaEd/+dX+SMcztQ29yxr6F"
        ];
      };
      root = {
        openssh.authorizedKeys.keys = [
          "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIDwg1laitTiNQACiFHgUvm4PYT1b3Fug7hmzFlxlrII+ deployment-19-12-2024"
        ];
      };
    };
  };

  system = {
    # include git rev of this repo/flake into the nixos-version
    configurationRevision = if inputs.self ? rev then lib.substring 0 8 inputs.self.rev else "dirty";

    nixos = {
      revision = inputs.nixpkgs.rev;
      versionSuffix = lib.mkForce ".${inputs.nixpkgs.shortRev}-${config.system.configurationRevision}";
    };

    tools.nixos-option.enable = false;
  };

  nix = {
    registry = {
      anderer.flake = inputs.self;
    };

    channel.enable = false;

    gc = {
      automatic = true;
      options = "--delete-older-than 7d";
      dates = "weekly";
      randomizedDelaySec = "42min";
    };

    settings = {
      trusted-users = [
        "@wheel"
      ];
      connect-timeout = 3;
      http-connections = 150;
      extra-experimental-features = [
        "flakes"
        "nix-command"
      ];
      builders-use-substitutes = true;
      log-lines = lib.mkDefault 25;
      narinfo-cache-negative-ttl = 300;
    };

    daemonCPUSchedPolicy = lib.mkDefault "batch";
    daemonIOSchedClass = lib.mkDefault "idle";
    daemonIOSchedPriority = lib.mkDefault 7;
  };
  systemd.services.nix-daemon.serviceConfig.LimitNOFILE = lib.mkForce "infinity";

  security = {
    sudo.enable = false;
    sudo-rs = {
      enable = true;
      execWheelOnly = lib.mkDefault true;
    };
    acme = {
      defaults.email = "social.depots@posteo.de";
      acceptTerms = true;
    };
  };

  virtualisation = {
    libvirtd = {
      qemu = {
        swtpm.enable = true;
      };
      onShutdown = lib.mkDefault "shutdown";
      onBoot = lib.mkDefault "ignore";
      parallelShutdown = lib.mkDefault 2;
    };
  };

  services = {
    speechd.enable = lib.mkDefault false;

    # I know how to find the nixos manual
    getty.helpLine = lib.mkForce "";

    resolved = {
      dnsovertls = "opportunistic";
      # no google/cloudflare defaults
      fallbackDns = [
        "2620:fe::10#dns.quad9.net"
        "2620:fe::fe:10#dns.quad9.net"
        "9.9.9.10#dns.quad9.net"
        "149.112.112.10#dns.quad9.net"
      ];
      # broken
      dnssec = "false";
    };

    journald.extraConfig = ''
      SystemMaxUse=100M
      MaxRetentionSec=3days
    '';

    userborn.enable = true;

    prometheus = {
      exporters.node = {
        enable = lib.mkDefault true;
        enabledCollectors = [
          "systemd"
          "processes"
        ];
      };
    };

    btrfs.autoScrub = lib.mkIf (config.fileSystems."/".fsType == "btrfs") {
      enable = true;
      fileSystems = [ "/" ];
    };
  };
}
