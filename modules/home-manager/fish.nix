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
    ];

    shellInitLast = ''
      # Disable shell greeting
      set -U fish_greeting

      # SSH authentication via Bitwarden
      set -gx SSH_AUTH_SOCK "/Users/joona/Library/Containers/com.bitwarden.desktop/Data/.bitwarden-ssh-agent.sock";

      # Vi mode
      set -g fish_key_bindings fish_vi_key_bindings
      bind -M command ctrl-e edit_command_buffer
    '';
  };
}
