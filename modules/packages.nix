{
  pkgs,
  lib,
  profile,
  isDarwin,
  ...
}:
{
  environment.systemPackages =
    (with pkgs; [
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
      typst

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

      nil
      nixd
      terraform
      gh
      bitwarden-cli
      claude-code
    ])
    # The daemon comes from the OrbStack cask; only the CLI is needed here.
    ++ lib.optionals isDarwin [ pkgs.docker ]
    ++ (import (./. + "/packages-${profile}.nix") { inherit pkgs; });
}
