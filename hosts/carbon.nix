{ lib, username, ... }:
{
  imports = [
    ../modules/packages/common.nix
    ../modules/packages/server.nix
    ../modules/home-manager
    ../modules/nixos/base.nix
    ../modules/nixos/hardware/carbon.nix
    ../modules/nixos/disko/carbon.nix
    ../modules/nixos/services/node-exporter.nix
    ../modules/nixos/services/web.nix
    ../modules/nixos/services/nixarr.nix
    ../modules/nixos/services/jellyfin.nix
    ../modules/nixos/services/qbittorrent.nix
  ];

  networking.networkmanager.enable = true;
  users.users.${username}.extraGroups = [ "networkmanager" ];

  users.mutableUsers = lib.mkForce true;

  console.keyMap = "fi";

  # Always on and headless, don't turn off when lid is closed
  services.logind.settings.Login = {
    HandleLidSwitch = "ignore";
    HandleLidSwitchExternalPower = "ignore";
    HandleLidSwitchDocked = "ignore";
  };
}
