{ pkgs, ... }:
{
  programs.neovim = {
    enable = true;
    defaultEditor = true;
    vimAlias = true;
    vimdiffAlias = true;

    withPython3 = false;
    withRuby = false;

    extraConfig = ''
      set clipboard=unnamedplus
      set relativenumber
      set termguicolors

      set expandtab
      set shiftwidth=2
      set tabstop=2
      set softtabstop=2
      set shiftround
      set smartindent
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
      {
        plugin = pkgs.vimPlugins.oil-nvim;
        type = "lua";
        config = ''
          require("oil").setup()
          vim.keymap.set("n", "-", "<CMD>Oil<CR>", { desc = "Open parent directory" })
        '';
      }
    ];
  };
}
