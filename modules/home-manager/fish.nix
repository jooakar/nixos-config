{ pkgs, username, ... }@inputs:
{
  programs.fish = {
    enable = true;
    generateCompletions = true;

    shellAliases = {
      "rg" = "rg --hidden --glob '!.git'";
      "cat" = "bat --style plain --paging=never";
    };

    plugins = [
      {
        name = "grc";
        src = pkgs.fishPlugins.grc.src;
      }
      {
        name = "plugin-git";
        src = pkgs.fishPlugins.plugin-git.src;
      }
    ];

    functions = {
      envsource = {
        description = "Source a .env file into the current shell";
        body = ''
          set -f envfile "$argv"
          if not test -f "$envfile"
            echo "Unable to load $envfile"
            return 1
          end
          while read line
            if not string match -qr '^#|^$' "$line"
              set item (string split -m 1 '=' $line)
              set -gx $item[1] $item[2]
              echo "Exported key $item[1]"
            end
          end < "$envfile"
        '';
      };
    };

    shellInitLast = ''
      # Disable shell greeting
      set -U fish_greeting

      # SSH authentication via Bitwarden
      set -gx SSH_AUTH_SOCK "/Users/${username}/Library/Containers/com.bitwarden.desktop/Data/.bitwarden-ssh-agent.sock";

      # Vi mode
      set -g fish_key_bindings fish_vi_key_bindings
      bind -M insert ctrl-e edit_command_buffer
    '';
  };
}
