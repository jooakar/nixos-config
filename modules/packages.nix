{ pkgs, ... }@input:
{
  environment.systemPackages = with pkgs; [
    fish
    direnv

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
    typst

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
    gh
    railway
  ];
}
