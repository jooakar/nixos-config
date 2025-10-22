{
  programs.neovim = {
    enable = true;
    defaultEditor = true;
    vimAlias = true;
    vimdiffAlias = true;

    extraConfig = ''
      set clipboard=unnamedplus
      set relativenumber
    '';
  };
}
