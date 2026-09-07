{
  config,
  lib,
  pkgs,
  inputs,
  flakeRoot,
  hostname,
  username,
  ...
}:
let
  # Every public key in the directory may log in
  authorizedKeys = lib.filesystem.listFilesRecursive (flakeRoot + /config/ssh-keys);
in
{
  imports = [
    inputs.disko.nixosModules.disko
    inputs.agenix.nixosModules.default
    ./hardware.nix
    ./disko.nix
    ./k3s.nix
    ./postgres.nix
  ];

  # System and Nix
  nixpkgs.hostPlatform = "x86_64-linux";
  nixpkgs.config.allowUnfree = true;
  nix.settings.experimental-features = [
    "flakes"
    "nix-command"
  ];
  nix.settings.trusted-users = [ username ];
  nix.optimise.automatic = true;
  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 14d";
  };
  system.stateVersion = "26.11";
  system.autoUpgrade = {
    enable = true;
    flake = "github:jooakar/nixos-config";
    dates = "weekly";
    randomizedDelaySec = "45min";
    allowReboot = false;
  };

  networking.hostName = hostname;
  time.timeZone = "Europe/Helsinki";
  i18n.defaultLocale = "en_US.UTF-8";

  boot.tmp.cleanOnBoot = true;
  zramSwap.enable = true;
  swapDevices = [
    {
      device = "/swapfile";
      size = 4096;
    }
  ];

  # User(s). Keys only, so wheel must not need a password it does not have.
  users.mutableUsers = false;
  users.users.${username} = {
    isNormalUser = true;
    extraGroups = [ "wheel" ];
    shell = pkgs.fish;
    openssh.authorizedKeys.keyFiles = authorizedKeys;
  };
  users.users.root.openssh.authorizedKeys.keyFiles = authorizedKeys;
  security.sudo.wheelNeedsPassword = false;
  programs.fish.enable = true;

  # Services
  services.openssh = {
    enable = true;
    settings = {
      PasswordAuthentication = false;
      KbdInteractiveAuthentication = false;
      PermitRootLogin = "prohibit-password";
    };
  };

  services.fail2ban = {
    enable = true;
    ignoreIP = [
      "127.0.0.0/8"
      "100.64.0.0/10"
    ];
  };

  services.tailscale = {
    enable = true;
    useRoutingFeatures = "client";
  };

  services.qemuGuest.enable = true;

  networking.firewall = {
    enable = true;
    allowedTCPPorts = [ 22 ];
    allowedUDPPorts = [ config.services.tailscale.port ];
    trustedInterfaces = [ "tailscale0" ];
  };
}
