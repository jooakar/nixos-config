{ ... }:
{
  boot.initrd.availableKernelModules = [
    "ahci"
    "xhci_pci"
    "virtio_pci"
    "virtio_scsi"
    "virtio_blk"
    "sd_mod"
    "sr_mod"
  ];
  hardware.enableRedistributableFirmware = true;

  # Boot on either firmware: disko points grub.devices at the disk holding the
  # bios_grub partition, which installs the i386-pc image, and efiSupport
  # additionally installs the removable-path EFI image into the ESP.
  boot.loader.grub = {
    enable = true;
    efiSupport = true;
    efiInstallAsRemovable = true;
  };
  boot.loader.efi.canTouchEfiVariables = false;
}
