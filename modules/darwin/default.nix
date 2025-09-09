{ pkgs, ... }@inputs:
{
  nixpkgs.hostPlatform = "aarch64-darwin";
  system.stateVersion = 6;
  system.primaryUser = "joona";
  programs.fish.enable = true;
  users.users.joona = {
    home = "/Users/joona";
    shell = pkgs.fish;
  };
  nix.settings.experimental-features = [
    "flakes"
    "nix-command"
  ];

  nix-homebrew.darwinModules.nix-homebrew
  {
    nix-homebrew = {
      # Install Homebrew under the default prefix
      enable = true;

      # Apple Silicon Only: Also install Homebrew under the default Intel prefix for Rosetta 2
      enableRosetta = true;

      # User owning the Homebrew prefix
      user = "joona";
    };
  }
  homebrew = {
    enable = true;
    casks = [
      "orbstack"
      "ghostty"
      "spotify"
      "brave-browser"
      "zoom"
      "visual-studio-code"
    ];
    onActivation = {
      autoUpdate = true;
      upgrade = true;
    };
    taps = [ ];
    # These app IDs are from using the mas CLI app
    # mas = mac app store
    # https://github.com/mas-cli/mas
    #
    # $ nix shell nixpkgs#mas
    # $ mas search <app name>
    #
    # completions from nixpkgs not work for some reason
    brews = [
      "mas"
    ];
    masApps = {
      "telegram" = 747648890;
      "bitwarden" = 1352778147;
    };
  };
}
