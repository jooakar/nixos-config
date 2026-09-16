{ lib, username, ... }:
{
  imports = [
    ../modules/packages/common.nix
    ../modules/packages/server.nix
    ../modules/home-manager
    ../modules/nixos/base.nix
    ../modules/nixos/hardware/carbon.nix
    ../modules/nixos/disko/carbon.nix
  ];

  joona.services = {
    nixarr.enable = true;
    jellyfin.enable = true;
    qbittorrent.enable = true;
    mousehole.enable = true;
    ddns.enable = true;
    node-exporter.enable = true;
  };

  networking.networkmanager.enable = true;
  users.users.${username}.extraGroups = [ "networkmanager" ];

  # The router's IPv6 firewall rules name a whole address, so the suffix has to
  # be one that does not move.
  networking.networkmanager.connectionConfig = {
    "ipv6.addr-gen-mode" = 0;
    "ipv6.ip6-privacy" = 0;
  };
  services.fail2ban.ignoreIP = [ "192.168.50.0/24" ];
  users.mutableUsers = lib.mkForce true;
  console.keyMap = "fi";

  # Always on and headless, don't turn off when lid is closed
  services.logind.settings.Login = {
    HandleLidSwitch = "ignore";
    HandleLidSwitchExternalPower = "ignore";
    HandleLidSwitchDocked = "ignore";
  };
}
