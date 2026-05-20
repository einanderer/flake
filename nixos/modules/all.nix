{ ... }:
{
  imports = [
    ./core.nix
    ./default/default.nix
    ./network/default.nix
    ./hardware/default.nix
    ./workstation/default.nix
    ./server/default.nix
    ./profiles/default.nix
    ./home.nix
    ./secureboot.nix
    ./nixpkgs.nix
  ];
}
