{ ... }:
{
  flake.nixosModules = {
    all = {
      imports = [ ./modules/all.nix ];
    };
  };
}
