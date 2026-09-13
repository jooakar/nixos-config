resource "upcloud_server" "vps" {
  hostname = var.hostname
  title    = "${var.hostname} (nixos)"
  zone     = var.zone
  plan     = var.plan
  metadata = true
  firewall = true

  # kexec does not work on UpCloud, so the installer comes from a CD instead.
  boot_order = "cdrom,disk"

  dynamic "storage_devices" {
    for_each = var.bootstrap ? [1] : []
    content {
      storage = var.installer_cdrom
      type    = "cdrom"
    }
  }

  template {
    storage = var.template_storage
    size    = var.storage_size

    # Disko owns the partition table from the first install onwards.
    filesystem_autoresize = false
  }

  network_interface {
    type = "public"
  }

  login {
    user              = "root"
    keys              = [var.ssh_public_key]
    create_password   = false
    password_delivery = "none"
  }

  lifecycle {
    ignore_changes = [template[0].storage]
  }
}

locals {
  ephemeral_start = "32768"
  ephemeral_end   = "60999"

  inbound = [
    { protocol = "tcp", start = "22", end = "22", comment = "ssh" },
    { protocol = "tcp", start = "80", end = "80", comment = "http" },
    { protocol = "tcp", start = "443", end = "443", comment = "https" },
    { protocol = "udp", start = "41641", end = "41641", comment = "tailscale" },
    { protocol = "tcp", start = local.ephemeral_start, end = local.ephemeral_end, comment = "return traffic" },
    { protocol = "udp", start = local.ephemeral_start, end = local.ephemeral_end, comment = "return traffic" },
  ]

  families = ["IPv4", "IPv6"]

  inbound_rules = flatten([
    for family in local.families : [
      for rule in local.inbound : merge(rule, { family = family })
    ]
  ])
}

resource "upcloud_firewall_rules" "vps" {
  server_id = upcloud_server.vps.id

  dynamic "firewall_rule" {
    for_each = local.inbound_rules
    content {
      action                 = "accept"
      direction              = "in"
      family                 = firewall_rule.value.family
      protocol               = firewall_rule.value.protocol
      destination_port_start = firewall_rule.value.start
      destination_port_end   = firewall_rule.value.end
      comment                = firewall_rule.value.comment
    }
  }

  # ICMPv6 carries neighbour discovery and PMTU; dropping it breaks IPv6.
  dynamic "firewall_rule" {
    for_each = local.families
    content {
      action    = "accept"
      direction = "in"
      family    = firewall_rule.value
      protocol  = "icmp"
      comment   = "icmp"
    }
  }

  # Defaults have to come last. Outbound is unrestricted; the host decides.
  firewall_rule {
    action    = "accept"
    direction = "out"
    comment   = "default out"
  }

  firewall_rule {
    action    = "drop"
    direction = "in"
    comment   = "default in"
  }
}
