{ ... }:
{
  imports = [
    ./core.nix
    ./base/default.nix
    ./network/default.nix
    ./hardware/default.nix
    ./workstation/default.nix
    ./profiles/default.nix
    ./home.nix
    ./secureboot.nix
    ./nixpkgs.nix
    ./default/nh-admin-gate.nix
  ];
}
