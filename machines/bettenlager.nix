{
  pkgs,
  ...
}:

{
  system.stateVersion = "25.11";

  fileSystems."/" = {
    device = "/dev/disk/by-uuid/68d49c06-e2dd-4da2-8e49-2524e58a2da5";
    fsType = "ext4";
  };

  fileSystems."/boot" = {
    device = "/dev/disk/by-uuid/E325-CA2A";
    fsType = "vfat";
    options = [
      "fmask=0077"
      "dmask=0077"
    ];
  };

  networking.hostName = "bettenlager";

  anderer.profiles.workstation.enable = true;
  anderer.profiles.workstationLaptop.enable = true;

  environment.systemPackages = [ pkgs.unzip ];

  anderer.hardware.thinkpad.x230 = true;

  anderer.os.workstation.gaming = {
    enable = true;
    remotePlay.enable = true;
  };

}
