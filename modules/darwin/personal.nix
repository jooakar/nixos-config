{ username, ... }:
{
  homebrew.casks = [
    "orbstack"
    "discord"
    "zoom"
    "skim"
    "vlc"
    "tailscale-app"
  ];

  home-manager.users.${username}.programs.ssh.includes = [ "~/.orbstack/ssh/config" ];
}
