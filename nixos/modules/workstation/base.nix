{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:
let
  cfg = config.anderer.os.workstation;
  inherit (lib) mkIf;
in
{
  config = mkIf cfg.enable {
    nixpkgs.overlays = [ inputs.bad_gateway.overlays.default ];

    services.dbus.implementation = "broker";

    xdg = {
      icons.enable = true;
      menus.enable = true;
      mime.enable = true;
      portal.enable = true;
    };

    security = {
      polkit = {
        enable = true;
        extraConfig = ''
          polkit.addRule(function(action, subject) {
            if (subject.isInGroup("wheel")) {
              return polkit.Result.YES;
            }
          });
        '';
      };
      pam.loginLimits = [
        # Allow audio group to set RT priorities
        {
          domain = "@audio";
          item = "memlock";
          type = "-";
          value = "unlimited";
        }
        {
          domain = "@audio";
          item = "rtprio";
          type = "-";
          value = "99";
        }
        {
          domain = "@audio";
          item = "nice";
          type = "soft";
          value = "-11";
        }
        {
          domain = "@audio";
          item = "nice";
          type = "hard";
          value = "-15";
        }
        {
          domain = "@audio";
          item = "nofile";
          type = "soft";
          value = "524288";
        }
        {
          domain = "@audio";
          item = "nofile";
          type = "hard";
          value = "524288";
        }
      ];
    };

    location = {
      latitude = 48.0;
      longitude = 11.0;
    };
    services.geoclue2.enable = lib.mkForce false;
    services.udisks2.enable = true;
    services.gnome.gnome-keyring.enable = false;

    services.logind = {
      settings = {
        Login = {
          HandleLidSwitchDocked = "lock";
          HandleLidSwitchExternalPower = "lock";
          HandleLidSwitch = "lock";
          HandlePowerKey = "lock";
        };
      };
    };

    services.printing = {
      enable = true;
      drivers = with pkgs; [
        foomatic-filters
        gutenprint
      ];
    };

    systemd.services."cups-browsed".wantedBy = lib.mkForce [ ];

    powerManagement.cpuFreqGovernor = if cfg.battery then "schedutil" else "performance";

    services.upower.enable = mkIf cfg.battery true;

    hardware.graphics = {
      enable = true;
      extraPackages = lib.optionals (pkgs.stdenv.hostPlatform.isx86) [
        pkgs.vulkan-validation-layers
      ];
    };
  };
}
