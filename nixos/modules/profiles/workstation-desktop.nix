{
  config,
  lib,
  ...
}:
{
  options.anderer.profiles.workstationDesktop.enable = lib.mkEnableOption ''
    Desktop workstation defaults (Ethernet-only network policy by default).
    Use together with anderer.profiles.workstation.
  '';

  config = lib.mkIf config.anderer.profiles.workstationDesktop.enable {
    anderer.os.workstation.network.publicUplinks = lib.mkDefault [ ];
    anderer.os.workstation.battery = lib.mkDefault false;
  };
}
