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
    nodejs_24
    python3
    docker

    ffmpeg

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

    nil
    nixd
    terraform
    railway
  ];
}
