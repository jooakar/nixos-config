{
  pkgs,
  nix-homebrew,
  profile,
  hostname,
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
    "claude"
    "slack"
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
  nix.settings.trusted-users = [ "joona" ];
  system.stateVersion = 6;
  system.primaryUser = "joona";
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
      tilesize = 24;
    };

    finder = {
      _FXShowPosixPathInTitle = false;
    };
  };

  local.dock.enable = true;
  local.dock.entries = [
    { path = "/Applications/Ghostty.app/"; }
    { path = "/Applications/Brave Browser.app/"; }
    { path = "/Applications/Slack.app/"; }
    { path = "/System/Applications/System Settings.app"; }
    { path = "/Applications/Bitwarden.app"; }
    {
      path = "/Users/joona/Downloads/";
      section = "others";
    }
  ];
  local.dock.username = "joona";

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
    casks = sharedCasks ++ profileOverlay.casks;
    onActivation = {
      autoUpdate = true;
      upgrade = true;
    };
    taps = profileOverlay.taps;
    brews = profileOverlay.brews;
  };
}
