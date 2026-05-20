{
  config,
  lib,
  ...
}:
{
  options.anderer.profiles.workstation.enable = lib.mkEnableOption ''
    Common settings for interactive NixOS workstations (timezone, boot loader, workstation role).
  '';

  config = lib.mkIf config.anderer.profiles.workstation.enable {
    time.timeZone = lib.mkForce "Europe/Berlin";
    boot.loader.systemd-boot.enable = lib.mkDefault true;
    anderer.secureboot = lib.mkDefault false;

    anderer.os.workstation.enable = lib.mkDefault true;
    anderer.os.workstation.cursor.enable = lib.mkDefault true;
  };
}
