output "ipv4_address" {
  value = upcloud_server.vps.network_interface[0].ip_address
}

output "ssh" {
  value = "ssh joona@${upcloud_server.vps.network_interface[0].ip_address}"
}

output "install_command" {
  value = join(" ", [
    "nix run github:nix-community/nixos-anywhere --",
    "--flake path:.#${var.hostname}",
    "--target-host root@${upcloud_server.vps.network_interface[0].ip_address}",
    "--build-on-remote",
    "--env-password",
    "--phases disko,install",
  ])
}
