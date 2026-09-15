{ inputs, pkgs, ... }:
{
  # A 5th-gen ThinkPad X1 Carbon
  imports = with inputs.nixos-hardware.nixosModules; [
    lenovo-thinkpad-x1
    common-pc-ssd
  ];

  boot.initrd.availableKernelModules = [
    "xhci_pci"
    "nvme"
    "thunderbolt"
    "usb_storage"
    "sd_mod"
  ];
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  hardware.enableRedistributableFirmware = true;
  # Gen9.5 QuickSync, which iHD covers and the newer oneVPL runtime does not.
  hardware.graphics = {
    enable = true;
    extraPackages = [ pkgs.intel-media-driver ];
  };
  hardware.trackpoint.device = "TPPS/2 Elan TrackPoint";
  services.thermald.enable = true;
  services.fwupd.enable = true;

  # A laptop that never moves and is never idle: full speed on AC, and the battery
  # parked at a storage charge rather than held at 100% forever.
  services.tlp.settings = {
    CPU_SCALING_GOVERNOR_ON_AC = "performance";
    CPU_ENERGY_PERF_POLICY_ON_AC = "performance";
    START_CHARGE_THRESH_BAT0 = 75;
    STOP_CHARGE_THRESH_BAT0 = 80;
  };
}
