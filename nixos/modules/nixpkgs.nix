{ config, lib, ... }:
let
  cfg = config.nixpkgs;
in
{
  options = {
    nixpkgs.permittedUnfreePackages = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      example = lib.literalExpression "[\"hplip\"]";
      description = ''
        List of package names that would be permitted to use despite having an
        unfree license.
      '';
    };
  };

  config = {
    nixpkgs.permittedUnfreePackages = [
      "spotify"
      "steam"
      "steam-unwrapped"
      "1password"
      "1password-cli"
      "intel-ocl"
      "geekbench"
    ];
    nixpkgs.config.allowUnfreePredicate =
      pkg: builtins.elem (lib.getName pkg) cfg.permittedUnfreePackages;
  };
}
