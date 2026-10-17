{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.anderer.os.workstation;
  inherit (lib) mkIf;
in
{
  config = mkIf cfg.enable {
    services.udev.extraRules = ''
      # SDRs
      ATTR{idVendor}=="1d50", ATTR{idProduct}=="604b", SYMLINK+="hackrf-jawbreaker-%k", TAG+="uaccess"
      ATTR{idVendor}=="1d50", ATTR{idProduct}=="6089", SYMLINK+="hackrf-one-%k", TAG+="uaccess"
      ATTR{idVendor}=="1d50", ATTR{idProduct}=="cc15", SYMLINK+="rad1o-%k", TAG+="uaccess"
      ATTR{idVendor}=="1fc9", ATTR{idProduct}=="000c", SYMLINK+="nxp-dfu-%k", TAG+="uaccess"

      # console/modem
      KERNEL=="ttyACM[0-9]*", TAG+="udev-acl", TAG+="uaccess"

      # pci runtime power management
      ACTION=="add", SUBSYSTEM=="pci", ATTR{power/control}="auto"

      # Keychron Q3 HE
      KERNEL=="hidraw*", SUBSYSTEM=="hidraw", ATTRS{idVendor}=="3434", ATTRS{idProduct}=="0b30", MODE="0666", GROUP="users", TAG+="uaccess", TAG+="udev-acl"
      # Keychron Q3 HE stm bootloader
      SUBSYSTEM=="usb", ATTRS{idVendor}=="0483", ATTRS{idProduct}=="df11", MODE="0666", GROUP="users", TAG+="uaccess", TAG+="udev-acl"
      # Keychron-Link
      SUBSYSTEM=="usb", ATTRS{idVendor}=="3434", ATTRS{idProduct}=="d030", MODE="0666", GROUP="users", TAG+="uaccess", TAG+="udev-acl"
    ''
    + (lib.optionalString cfg.battery ''
      ACTION=="add|move", SUBSYSTEM=="net", ENV{INTERFACE}=="enp*", RUN+="${lib.getExe pkgs.ethtool} -s %k wol d"
      ACTION=="add|move", SUBSYSTEM=="net", ENV{INTERFACE}=="wlp*", RUN+="${lib.getExe pkgs.iw} dev %k set power_save on"
      ACTION=="add", SUBSYSTEM=="scsi_host", KERNEL=="host*", ATTR{link_power_management_policy}="med_power_with_dipm"

      # Autosuspend for Generic EMV Smartcard Reader
      ACTION=="add", SUBSYSTEM=="usb", ATTR{idVendor}=="2ce3", ATTR{idProduct}=="9563", TEST=="power/control", ATTR{power/control}="auto"

      # Rule for when switching to battery
      ACTION=="change", SUBSYSTEM=="power_supply", ATTRS{type}=="Mains", ATTRS{online}=="0", RUN+="${pkgs.systemd}/bin/systemd-run --machine=${config.anderer.home.user}@.host --user ${lib.getExe pkgs.libnotify} -a Power -i battery-full 'Using battery power'"
      # Rule for when switching to AC
      ACTION=="change", SUBSYSTEM=="power_supply", ATTRS{type}=="Mains", ATTRS{online}=="1", RUN+="${pkgs.systemd}/bin/systemd-run --machine=${config.anderer.home.user}@.host --user ${lib.getExe pkgs.libnotify} -a Power -i battery-full-charging 'Using AC power'"

      # Battery warnings
      SUBSYSTEM=="power_supply", ATTR{status}=="Discharging", ATTR{capacity}=="15", RUN+="${pkgs.systemd}/bin/systemd-run --machine=${config.anderer.home.user}@.host --user ${lib.getExe pkgs.libnotify} -a Power -i battery-low 'Battery Power Low' 'Less than 15%% battery remaining'"
      SUBSYSTEM=="power_supply", ATTR{status}=="Discharging", ATTR{capacity}=="5", RUN+="${pkgs.systemd}/bin/systemd-run --machine=${config.anderer.home.user}@.host --user ${lib.getExe pkgs.libnotify} -a Power -i battery-empty 'Battery Power Critical' 'Less than 5%% battery remaining'"

      # Suspend when battery is at 2%
      SUBSYSTEM=="power_supply", ATTR{status}=="Discharging", ATTR{capacity}=="[0-2]", RUN+="${pkgs.systemd}/bin/systemctl suspend"
    '');
  };
}
