{
  config,
  lib,
  ...
}:
let
  cfg = config.bpletza.workstation;
  inherit (lib) mkEnableOption mkIf;
in
{
  options.bpletza.workstation.filesystems = mkEnableOption "Filesystems" // {
    default = config.bpletza.workstation.enable;
  };

  config = mkIf cfg.filesystems {
    sops.secrets = {
      smb-secrets = {
        sopsFile = ../../../secrets.yaml;
      };
    };

    fileSystems."/mnt/DATA" = {
      device = "//10.0.0.1/DATA";
      fsType = "cifs";
      options =
        let
          automount_opts = "x-systemd.automount,noauto,x-systemd.idle-timeout=60,x-systemd.device-timeout=5s,x-systemd.mount-timeout=5s";
        in
        [ "${automount_opts},credentials=${config.sops.secrets.smb-secrets.path},uid=1000,gid=100" ];
    };
  };
}
