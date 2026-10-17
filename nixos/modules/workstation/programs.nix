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
    programs.dconf.enable = true;
    # Disabled: nixpkgs iotop is a bash-wrapped Python script, fails the new
    # ensure-wrapper-integrity check (target must be an ELF). Enable again once
    # upstream fixes the packaging.
    programs.iotop.enable = false;
    programs.wireshark = {
      enable = true;
      package = pkgs.wireshark;
    };
    programs.flashrom.enable = true;
    programs.git.package = pkgs.git;

    programs.nh.enable = true;

    programs.ssh.knownHosts = {
      # "bauwagen.env.club.muc.ccc.de".publicKey =
      # "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIFXa8mFvlyGE+zJv6u2SybG9+W/wA0FIkl7th45K6g80";
      "10.0.0.50".publicKey =
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIIxLv1bbV62V1t4k2rUjITBlPPgTiBvmPDAwzWTJq0QH root@nixos";
    };

    services.xserver = {
      xkb = {
        layout = "eu";
        options = "compose:caps";
      };
    };
  };
}
