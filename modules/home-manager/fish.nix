{ pkgs, ... }@inputs:
{
  programs.fish = {
    enable = true;
    generateCompletions = true;

    shellAliases = {
      "rg" = "rg --hidden --glob '!.git'";
      "cat" = "bat --style plain --paging=never";
    };

    plugins = [
      { name = "grc"; src = pkgs.fishPlugins.grc.src; }
      { name = "plugin-git"; src = pkgs.fishPlugins.plugin-git.src; }
      { name = "git-abbr"; src = pkgs.fishPlugins.git-abbr.src; }
    ];

    shellInitLast = ''
      set -x SSH_AUTH_SOCK = "/Users/joona/Library/Containers/com.bitwarden.desktop/Data/.bitwarden-ssh-agent.sock";
    '';
  };
}
