{ lib, inputs, ... }:
{
  perSystem =
    { pkgs, system, ... }:
    let
      byNamePackages =
        pkgs:
        lib.filesystem.packagesFromDirectoryRecursive {
          inherit (pkgs) callPackage;
          directory = ./by-name;
        };
    in
    {
      _module.args.pkgs = import inputs.nixpkgs {
        inherit system;
        overlays = [
          inputs.self.overlays.default
        ];
        config.allowUnfreePredicate =
          pkg:
          builtins.elem (lib.getName pkg) [
            "barbar.nvim"
            "git-conflict.nvim"
          ];
      };

      packages = {
        nvim = inputs.nixvim.legacyPackages.${system}.makeNixvimWithModule {
          inherit pkgs;
          module = import ../home/nixvim;
        };
      }
      // byNamePackages pkgs;

      formatter = pkgs.treefmt;
    };

  flake.overlays.default = final: prev: {
    tailscale = prev.tailscale.overrideAttrs (
      {
        patches ? [ ],
        ...
      }:
      {
        patches = patches ++ [ ../static/tailscale-magicdns-aaaa.patch ];
        doCheck = false;
      }
    );

    linuxPackages-xanmod = final.linuxPackagesFor final.linux-xanmod;

    lutris-free = prev.lutris-free.override {
      lutris = prev.lutris.override {
        buildFHSEnv =
          args:
          final.buildFHSEnv (
            args
            // {
              multiPkgs =
                envPkgs:
                let
                  originalPkgs = args.multiPkgs envPkgs;
                  customLdap = envPkgs.openldap.overrideAttrs (_: {
                    doCheck = false;
                  });
                in
                builtins.filter (p: (p.pname or "") != "openldap") originalPkgs ++ [ customLdap ];
            }
          );
      };
    };
  };
}
