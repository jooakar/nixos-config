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
  ];

  networking.networkmanager.enable = true;
  users.users.${username}.extraGroups = [ "networkmanager" ];

  # The vps is key-only and publicly reachable, so it stays fully declarative.
  # With mutableUsers = false activation rewrites every shadow entry to "!" on
  # each boot, which makes a console password impossible to keep. This machine
  # is physically in reach, so the nixpkgs default applies instead and `passwd`
  # sticks.
  users.mutableUsers = lib.mkForce true;

  # Finnish keycaps. This reaches the initrd too, so the LUKS prompt matches the
  # layout the passphrase was created under.
  console.keyMap = "fi";

  # Always on and headless: the lid is not a power switch.
  services.logind.settings.Login = {
    HandleLidSwitch = "ignore";
    HandleLidSwitchExternalPower = "ignore";
    HandleLidSwitchDocked = "ignore";
  };
}
