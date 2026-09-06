{
  lib,
  inputs,
  flakeRoot,
  profile,
  username,
  email,
  isDarwin,
  ...
}:

let
  configPath = flakeRoot + /config;
  hostModules =
    if isDarwin then inputs.home-manager.darwinModules else inputs.home-manager.nixosModules;
in
{
  imports = [
    hostModules.home-manager
  ];

  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    backupFileExtension = "hm-backup";
    extraSpecialArgs = {
      inherit
        profile
        username
        email
        isDarwin
        ;
    };
    users.${username} = {
      xdg.enable = true;
      xdg.configFile = lib.optionalAttrs isDarwin {
        "ghostty".source = configPath + /ghostty;
        "aerospace".source = configPath + /aerospace;
      };

      home.file = {
        ".claude/CLAUDE.md".source = configPath + /AGENTS.md;
        ".gemini/GEMINI.md".source = configPath + /AGENTS.md;
        ".codex/AGENTS.md".source = configPath + /AGENTS.md;
        ".ssh/bitwarden_github.pub".source = configPath + /ssh/bitwarden_github.pub;
      };

      home.stateVersion = "24.11";
      imports = [
        inputs.nix-index-database.homeModules.nix-index
        {
          programs.nix-index-database.comma.enable = true;
        }
        ./nvim.nix
        ./tmux.nix
        ./fish.nix
        ./git.nix
        ./ssh.nix
      ];
      # generic packages
      programs = {
        atuin = {
          enable = true;
          flags = [
            "--disable-up-arrow"
          ];
          enableFishIntegration = true;
        };
        zoxide = {
          enable = true;
          options = [
            "--cmd cd"
          ];
          enableFishIntegration = true;
        };
        direnv = {
          enable = true;
          nix-direnv.enable = true;
        };
      };
    };
  };
}
