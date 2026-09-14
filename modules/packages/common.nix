{ pkgs, ... }:
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

    ffmpeg

    grc
    git
    jujutsu
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
