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
  options.bpletza.workstation._1password = mkEnableOption "1Password support" // {
    default = config.bpletza.workstation.enable;
  };

  config = mkIf cfg._1password {
    programs._1password.enable = true;
    programs._1password-gui = {
      enable = true;
      polkitPolicyOwners = [ "anderer" ];
    };
    programs.ssh = {
      extraConfig = ''
        Host *
            IdentityAgent /home/anderer/.1password/agent.sock
      '';
    };
  };
}
