{ pkgs, nix-homebrew, ... }@inputs:
{
  imports = [
    nix-homebrew.darwinModules.nix-homebrew
  ];
  
  # System and Nix
  nixpkgs.hostPlatform = "aarch64-darwin";
  nix.settings.experimental-features = ["flakes" "nix-command"];
  system.stateVersion = 6;
  system.primaryUser = "joona";
  networking.hostName = "maxos";

  # MacOS settings
  security.pam.services.sudo_local.touchIdAuth = true;

  # User(s)
  users.knownUsers = [ "joona" ];
  users.users.joona = {
    home = "/Users/joona";
    uid = 501;
    shell = pkgs.fish;
  };
  programs.fish.enable = true;

  # Homebrew
  nix-homebrew = {
    enable = true;
    enableRosetta = true;
    user = "joona";
  };

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
