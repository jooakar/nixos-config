{ pkgs, ... }@input:
{
 environment.systemPackages = with pkgs; [
    fish

    btop
    rclone
    sqlite
    postgresql
    coreutils
    tldr

    clang
    gcc
    rustup
    go
    nodejs
    python3

    ffmpeg

    comma
    grc
    git
    bat
    jq
    fd
    fzf
    ripgrep
    zoxide
    atuin
    tmux
    unzip
    zip
  ];
}
