{
  config,
  lib,
  ...
}:
{
  options.anderer.profiles.workstationLaptop.enable = lib.mkEnableOption ''
    Laptop workstation defaults (battery, no libvirt by default).
    Use together with anderer.profiles.workstation.
  '';

  config = lib.mkIf config.anderer.profiles.workstationLaptop.enable {
    anderer.os.workstation.battery = lib.mkDefault true;
  };
}
