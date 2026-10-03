{
  lib,
  pkgs,
  ...
}:
{
  keymaps = [
    {
      mode = "n";
      key = "<leader>l";
      action.__raw = ''
        function()
          vim.diagnostic.config({ virtual_lines = not vim.diagnostic.config().virtual_lines, virtual_text = vim.diagnostic.config().virtual_lines })
        end
      '';
      options.desc = "Toggle lsp virtual lines";
    }
    {
      mode = "n";
      key = "<leader>L";
      action.__raw = ''
        function()
          vim.lsp.inlay_hint.enable(not vim.lsp.inlay_hint.is_enabled())
        end
      '';
      options.desc = "Toggle lsp inlay hints";
    }
    {
      mode = "n";
      key = "<leader>k";
      action = lib.nixvim.mkRaw "function() vim.diagnostic.jump({ count=-1, float=true }) end";
    }
    {
      mode = "n";
      key = "<leader>j";
      action = lib.nixvim.mkRaw "function() vim.diagnostic.jump({ count=1, float=true }) end";
    }
    {
      mode = "n";
      key = "<leader>lx";
      action = "<CMD>LspStop<Enter>";
    }
    {
      mode = "n";
      key = "<leader>ls";
      action = "<CMD>LspStart<Enter>";
    }
    {
      mode = "n";
      key = "<leader>lr";
      action = "<CMD>LspRestart<Enter>";
    }
    {
      mode = "n";
      key = "rn";
      lspBufAction = "rename";
    }
    {
      mode = "n";
      key = "ca";
      lspBufAction = "code_action";
    }
  ];

  lsp = {
    servers = {
      bashls.enable = true;
      basedpyright.enable = true;
      clangd.enable = true;
      cssls.enable = true;
      docker_compose_language_service.enable = true;
      dockerls.enable = true;
      gopls.enable = true;
      html.enable = true;
      jsonls.enable = true;
      just.enable = true;
      lemminx.enable = true;
      lua_ls.enable = true;
      nixd = {
        enable = true;
        config =
          let
            localFlake = ''(builtins.getFlake "/home/anderer/flake")'';
          in
          {
            nixpkgs.expr = "import <nixpkgs> {}";
            formatting.command = [ (lib.getExe pkgs.nixfmt) ];
            options = {
              nixos.expr = "${localFlake}.nixosConfigurations.amateur.options";
              home-manager.expr = "${localFlake}.homeConfigurations.anderer.options";
            };
          };
      };
      marksman.enable = true;
      markdown_oxide.enable = true;
      pylsp.enable = true;
      ruff.enable = true;
      taplo.enable = true;
      texlab.enable = false;
      yamlls.enable = true;
      zls.enable = true;
    };
  };

  plugins = {
    rustaceanvim = {
      enable = true;
      settings.server = {
        standalone = false;
      };
    };
    typescript-tools = {
      enable = true;
      settings.settings = {
        expose_as_code_action = "all";
      };
    };
    otter.enable = true;
  };
}
