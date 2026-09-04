{
  programs.ssh = {
    enable = true;
    enableDefaultConfig = false;
    includes = [ "~/.orbstack/ssh/config" ];
    settings = {
      "*" = {
        AddKeysToAgent = "yes";
        HashKnownHosts = false;
        SetEnv.TERM = "xterm-256color";
      };
      "github.com" = {
        HostName = "github.com";
        IdentityFile = "~/.ssh/bitwarden_github.pub";
        IdentitiesOnly = true;
      };
    };
  };
}
