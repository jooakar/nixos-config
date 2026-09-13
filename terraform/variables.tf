variable "hostname" {
  type        = string
  default     = "vps"
  description = "Must match a nixosConfigurations.<name> in the NixOS flake."
}

variable "zone" {
  type    = string
  default = "fi-hel1"
}

variable "plan" {
  type    = string
  default = "STARTER-2xCPU-4GB"
}

variable "storage_size" {
  type        = number
  default     = 30
  description = "Must match the storage included in var.plan."
}

variable "template_storage" {
  type        = string
  default     = "Ubuntu Server 24.04 LTS (Noble Numbat)"
  description = "Only ever booted once; nixos-anywhere kexecs and overwrites the disk."
}

variable "ssh_public_key" {
  type        = string
  default     = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJSsuGp5k0SlENWdaMVCeuwiLurnwBBLaIRiXIx67JY3 jooakar"
  description = "Root key for the install. The same key is authorized by the NixOS config."
}

variable "bootstrap" {
  type        = bool
  default     = false
  description = "Boot from NixOS installer CD rather when true"
}

variable "installer_cdrom" {
  type        = string
  default     = "01000000-0000-4000-8000-000170010201"
  description = "NixOS 25.05 Minimal Installation CD. `upctl storage list --public` lists the alternatives."
}

variable "cloudflare_account_id" {
  type        = string
  default     = "d247563982d77af7026e8d7168647e81"
  description = "Same account that holds the R2 state bucket. An identifier, not a credential."
}

variable "tailscale_ip" {
  type        = string
  default     = "100.115.123.13"
  description = "The server's tailnet address, stable while the node stays in the tailnet."
}
