{ inputs, lib, flakeRoot, ... }:

let
  configPath = flakeRoot + /config;
in
{
  imports = [
    inputs.home-manager.darwinModules.home-manager
  ];

  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    users.joona = {
      xdg.enable = true;
      xdg.configFile = {
        "ghostty".source = configPath + /ghostty;
      };

      home.stateVersion = "25.11";
      imports = [
        inputs.nix-index-database.homeModules.nix-index
        {
          programs.nix-index-database.comma.enable = true;
        }
        ./nvim.nix
        ./tmux.nix
        ./fish.nix
        ./git.nix
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
      };
    };
  };
}
