{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.anderer.os.workstation;
  inherit (lib) mkIf mkDefault;
in
{
  config = mkIf cfg.enable {
    boot = {
      kernel.sysctl = {
        "vm.dirty_writeback_centisecs" = 3000;
        "net.ipv4.tcp_limit_output_bytes" = 65536;
        "fs.inotify.max_user_watches" = 524288;
        "kernel.nmi_watchdog" = 0;
      };
      kernelParams = [ "snd_hda_intel.power_save=1" ];
      loader.grub = {
        ipxe = {
          netbootxyz = ''
            dhcp
            chain --autofree https://boot.netboot.xyz
          '';
        };
        memtest86.enable = pkgs.stdenv.hostPlatform.isx86_64;
        efiSupport = mkDefault true;
      };
      loader.systemd-boot = {
        memtest86.enable = true;
        netbootxyz.enable = true;
      };
      # Update 21.10.2026 The option definition `boot.initrd.systemd.enable' no longer has any effect; please remove it.
      #initrd.systemd.enable = true;
      binfmt.emulatedSystems = lib.optional pkgs.stdenv.hostPlatform.isx86_64 "aarch64-linux";
    };

    systemd = {
      enableEmergencyMode = true;
      settings.Manager.DefaultTimeoutStopSec = "20s";
    };

    environment.systemPackages = [ pkgs.efibootmgr ];
  };
}
