{
  config,
  lib,
  ...
}:
let
  cfg = config.anderer.os.workstation;
  inherit (lib) mkIf mkDefault;
in
{
  config = mkIf cfg.enable {
    nix = {
      daemonCPUSchedPolicy = "idle";
      daemonIOSchedClass = "idle";
      settings = {
        keep-outputs = mkDefault true;
        keep-derivations = true;
      };
      distributedBuilds = true;
      buildMachines = [
        # {
        #   hostName = "bauwagen.env.club.muc.ccc.de";
        #   protocol = "ssh-ng";
        #   sshUser = "nix-build";
        #   sshKey = "/home/${config.anderer.home.user}/.ssh/id_build";
        #   systems = [
        #     "i686-linux"
        #     "x86_64-linux"
        #   ];
        #   supportedFeatures = [
        #     "kvm"
        #     "big-parallel"
        #     "nixos-test"
        #   ];
        #   maxJobs = 24;
        #   speedFactor = 6;
        # }
        {
          hostName = "10.0.0.50";
          protocol = "ssh-ng";
          sshUser = "nix-build";
          sshKey = "/home/${config.anderer.home.user}/.ssh/bauwagen_ed25519";
          systems = [
            "i686-linux"
            "x86_64-linux"
          ];
          supportedFeatures = [
            "kvm"
            "big-parallel"
            "nixos-test"
          ];
          maxJobs = 24;
          speedFactor = 6;
        }
      ];
    };
  };
}
