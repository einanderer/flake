{
  lib,
  inputs,
  config,
  ...
}:
let
  cfg = config.bpletza.home;
in
{
  options.bpletza.home = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "home management for user";
    };
    user = lib.mkOption {
      type = lib.types.str;
      default = "anderer";
      description = "username";
    };
    passwordFromSecrets = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Use secrets for password hash";
    };
  };

  imports = [ inputs.home-manager.nixosModules.default ];

  config = lib.mkIf cfg.enable {
    sops.secrets."${cfg.user}-password" = lib.mkIf cfg.passwordFromSecrets {
      sopsFile = ../../secrets.yaml;
      neededForUsers = true;
    };

    home-manager = lib.mkIf (!config.boot.isContainer) {
      useGlobalPkgs = true;
      useUserPackages = true;
      users.${cfg.user} = ../../home/${cfg.user}.nix;
      extraSpecialArgs = {
        inherit inputs;
      };
    };

    users = {
      users.${cfg.user} = {
        uid = 1000;
        isNormalUser = true;
        hashedPasswordFile =
          lib.mkIf cfg.passwordFromSecrets
            config.sops.secrets."${cfg.user}-password".path;
        group = "users";
        extraGroups = [
          "wheel"
          "libvirtd"
          "audio"
          "video"
          "docker"
          "sway"
          "wireshark"
          "input"
          "podman"
          "systemd-journal"
        ];
        home = "/home/${cfg.user}";
        shell = "/run/current-system/sw/bin/zsh";
        subGidRanges = [
          {
            count = 65536;
            startGid = 100001;
          }
        ];
        subUidRanges = [
          {
            count = 65536;
            startUid = 100001;
          }
        ];
        openssh.authorizedKeys.keys = [
          "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIDwg1laitTiNQACiFHgUvm4PYT1b3Fug7hmzFlxlrII+ deployment-19-12-2024"
          "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIN7IyhxIzMjHGq8dBi1jZDYfTBMRm7Z3l+U5ORNveh5e furry-12-08-2021"
        ];
      };
    };

    nix.settings.trusted-users = [ cfg.user ];
  };
}
