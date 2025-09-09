{ pkgs, ... }:
{
  programs.tmux = {
    enable = true;
    shortcut = "Space";
    clock24 = true;
    baseIndex = 1;
    keyMode = "vi";
    terminal = "xterm-256color";
    disableConfirmationPrompt = true;
    mouse = true;
    historyLimit = 8192;

    extraConfig = ''
      set -g renumber-windows on

      unbind-key -T copy-mode-vi v
      unbind-key C
      bind-key C copy-mode

      bind-key -T copy-mode-vi v send-keys -X begin-selection
      bind-key -T copy-mode-vi C-v send-keys -X rectangle-toggle
      bind-key -T copy-mode-vi y send-keys -X copy-pipe-and-cancel "pbcopy"
      bind-key -T copy-mode-vi MouseDragEnd1Pane send-keys -X copy-pipe-and-cancel "pbcopy"

      bind c new-window -c '#{pane_current_path}'

      set -g status-position top
      set -g status-justify centre
      set -g status-style "bg=default"
      set -g window-status-current-style "fg=blue,bold"
      set -g status-right ""
      set -g status-left "#S"
    '';
  };
}
