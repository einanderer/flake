{
  self,
  withSystem,
  inputs,
  ...
}:
{
  flake.nixosConfigurations =
    let
      nixos =
        {
          system,
          modules ? [ ],
          module ? null,
        }:
        withSystem system (
          { config, inputs', ... }:
          inputs.nixpkgs.lib.nixosSystem {
            inherit system;
            modules =
              if modules != [ ] then
                modules
              else
                [
                  self.nixosModules.all
                  module
                ];
            specialArgs = {
              packages = config.packages;
              inherit inputs inputs';
            };
          }
        );
    in
    {
      server = nixos {
        system = "x86_64-linux";
        module = {
          networking.hostName = "server";
          fileSystems."/" = {
            device = "/dev/disk/by-label/nixos";
            fsType = "ext4";
          };
          boot.loader.systemd-boot = {
            enable = true;
          };
        };
      };

      trolllollo = nixos {
        system = "x86_64-linux";
        module = import ./trolllollo.nix;
      };

      amateur = nixos {
        system = "x86_64-linux";
        module = import ./amateur.nix;
      };
    };
}
