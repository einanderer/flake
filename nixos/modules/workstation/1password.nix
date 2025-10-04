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
    
    environment.variables = {
      SSH_AUTH_SOCK = "~/.1password/agent.sock";
    };
  };
}
