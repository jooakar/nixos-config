{ pkgs, ... }@input:
{
 environment.systemPackages = with pkgs; [
    btop
    rclone
    sqlite
    postgresql
    coreutils

    clang
    gcc
    rustup
    go
    nodejs
    python3

    ffmpeg

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
