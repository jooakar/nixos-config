{
  programs.zsh = {
    # deprecated, see fish.nix
    enable = true;
    enableCompletion = true;
    autosuggestion.enable = true;
    syntaxHighlighting.enable = true;

    shellAliases = {
      "ls" = "ls --color=auto";
      "rg" = "rg --hidden --glob '!.git'";
      "cat" = "bat --style plain --paging=never";
    };

    oh-my-zsh = {
      plugins = [
        "git"
      ];
    };

    sessionVariables = {
      SSH_AUTH_SOCK = "/Users/joona/Library/Containers/com.bitwarden.desktop/Data/.bitwarden-ssh-agent.sock";
    };
  };
}
