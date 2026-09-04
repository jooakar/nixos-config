{ pkgs, ... }:
{
  programs.neovim = {
    enable = true;
    defaultEditor = true;
    vimAlias = true;
    vimdiffAlias = true;

    extraConfig = ''
      set clipboard=unnamedplus
      set relativenumber
      set termguicolors
    '';

    plugins = [
      {
        plugin = pkgs.vimPlugins.neovim-ayu;
        type = "lua";
        config = ''
          require("ayu").setup({ mirage = false })
          vim.cmd.colorscheme("ayu-dark")
        '';
      }
    ];
  };
}
