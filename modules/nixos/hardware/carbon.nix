{ inputs, ... }:
{
  # A 5th-gen X1 Carbon. nixos-hardware has no module for that generation; the
  # generic one carries the trackpoint, TLP and the Intel CPU bits, and the SSD
  # trim timer its 6th-gen module adds is named here. The Kaby Lake module is
  # skipped deliberately: it only tunes i915, and this machine has no display.
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
