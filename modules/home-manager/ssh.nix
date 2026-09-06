{ lib, isDarwin, ... }:
{
  programs.ssh = {
    enable = true;
    enableDefaultConfig = false;
    includes = lib.optionals isDarwin [ "~/.orbstack/ssh/config" ];
    settings = {
      "*" = {
        AddKeysToAgent = "yes";
        HashKnownHosts = false;
        SetEnv.TERM = "xterm-256color";
      };
      "github.com" = {
        HostName = "github.com";
        IdentityFile = "~/.ssh/id_ed25519";
        IdentitiesOnly = true;
      };
    };
  };
}
