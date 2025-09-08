{
  nixpkgs.hostPlatform = "aarch64-darwin";
  system.stateVersion = 6;
  system.primaryUser = "joona";
  users.users.joona.home = "/Users/joona";
  nix.settings.experimental-features = [
    "flakes"
    "nix-command"
    "pipe-operators"
  ];

  homebrew = {
    enable = true;
    casks = [
      "orbstack"
      "ghostty"
      "spotify"
      "brave-browser"
      "zoom"
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
