{
  pkgs,
  nix-homebrew,
  profile,
  hostname,
  username,
  ...
}@inputs:
let
  profileOverlay = import (./. + "/${profile}.nix");
  sharedCasks = [
    "orbstack"
    "ghostty"
    "spotify"
    "brave-browser"
    "visual-studio-code"
    "zed"
    "nikitabobko/tap/aerospace"
    "beekeeper-studio"
    "bitwarden"
  ];
in
{
  imports = [
    nix-homebrew.darwinModules.nix-homebrew
  ];

  # System and Nix
  nixpkgs.hostPlatform = "aarch64-darwin";
  nixpkgs.config.allowUnfree = true;
  nix.settings.experimental-features = [
    "flakes"
    "nix-command"
  ];
  nix.settings.trusted-users = [ username ];
  system.stateVersion = 6;
  system.primaryUser = username;
  networking.hostName = hostname;

  # MacOS settings
  security.pam.services.sudo_local.touchIdAuth = true;

  system.keyboard = {
    enableKeyMapping = true;
    remapCapsLockToEscape = true;
  };

  # some of these are documented at https://macos-defaults.com/
  # https://daiderd.com/nix-darwin/manual/index.html#opt-system.defaults.CustomSystemPreferences
  system.defaults = {
    NSGlobalDomain = {
      AppleShowAllExtensions = true;
      ApplePressAndHoldEnabled = false;

      KeyRepeat = 2;
      InitialKeyRepeat = 25;
    };

    menuExtraClock = {
      Show24Hour = true;
      ShowDayOfWeek = true;
      ShowDate = 0;
      ShowSeconds = true;
    };

    dock = {
      autohide = true;
      show-recents = true;
      launchanim = true;
      orientation = "bottom";
      tilesize = 40;
    };

    finder = {
      _FXShowPosixPathInTitle = false;
    };
  };

  # User(s)
  users.knownUsers = [ username ];
  users.users.${username} = {
    home = "/Users/${username}";
    uid = 501;
    shell = pkgs.fish;
  };
  programs.fish.enable = true;

  # Homebrew
  nix-homebrew = {
    enable = true;
    enableRosetta = true;
    user = username;
  };

  homebrew = {
    enable = true;
    casks = sharedCasks ++ profileOverlay.casks;
    onActivation = {
      autoUpdate = true;
      upgrade = true;
    };
    taps = profileOverlay.taps;
    brews = profileOverlay.brews;
  };
}
