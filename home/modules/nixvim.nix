{
  lib,
  config,
  osConfig,
  inputs,
  pkgs,
  ...
}:
{
  options.anderer.nixvim = lib.mkOption {
    type = lib.types.bool;
    default = osConfig.anderer.workstation.enable;
  };

  config = lib.mkIf config.anderer.nixvim {
    home.packages = [ inputs.self.packages.${pkgs.stdenv.hostPlatform.system}.nvim ];

    home.sessionVariables = {
      EDITOR = "nvim";
    };

    home.shellAliases = {
      vim = "nvim";
      vimdiff = "nvim -d";
    };
  };
}
