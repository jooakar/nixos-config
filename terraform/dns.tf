resource "cloudflare_zone" "joona_codes" {
  account = { id = var.cloudflare_account_id }
  name    = "joona.codes"
  type    = "full"

  # destroy would delete the domain, not just its records
  lifecycle {
    prevent_destroy = true
  }
}

resource "cloudflare_zone" "hundred_app" {
  account = { id = var.cloudflare_account_id }
  name    = "hundred.app"
  type    = "full"

  lifecycle {
    prevent_destroy = true
  }
}

# =============================================
# joona.codes
# =============================================

resource "cloudflare_dns_record" "server" {
  for_each = toset([
    "joona.codes",
    "*.joona.codes",
  ])

  zone_id = cloudflare_zone.joona_codes.id
  name    = each.value
  type    = "A"
  content = upcloud_server.vps.network_interface[0].ip_address
  ttl     = 300
  proxied = false
}

# Tailnet-only services
resource "cloudflare_dns_record" "internal" {
  for_each = toset([
    "dns",
    "grafana",
  ])

  zone_id = cloudflare_zone.joona_codes.id
  name    = "${each.value}.joona.codes"
  type    = "A"
  content = var.tailscale_ip
  ttl     = 300
  proxied = false
}

# Tailnet-only services on carbon.
resource "cloudflare_dns_record" "carbon_internal" {
  for_each = toset([
    "qbt",
    "prowlarr",
    "sonarr",
    "radarr",
    "bazarr",
    "mousehole",
  ])

  zone_id = cloudflare_zone.joona_codes.id
  name    = "${each.value}.joona.codes"
  type    = "A"
  content = var.carbon_tailscale_ip
  ttl     = 300
  proxied = false
}

resource "cloudflare_dns_record" "home" {
  # dyndns fixes these to real addresses
  for_each = {
    A    = "192.0.2.1"
    AAAA = "2001:db8::1"
  }

  zone_id = cloudflare_zone.joona_codes.id
  name    = "home.joona.codes"
  type    = each.key
  content = each.value
  ttl     = 300
  proxied = false

  lifecycle {
    ignore_changes = [content]
  }
}

resource "cloudflare_dns_record" "carbon_public" {
  for_each = toset([
    "tv",
    "books",
    "seerr",
    "shelfmark",
  ])

  zone_id = cloudflare_zone.joona_codes.id
  name    = "${each.value}.joona.codes"
  type    = "CNAME"
  content = "home.joona.codes"
  ttl     = 300
  proxied = false

  settings = {
    flatten_cname = false
  }
}

# =============================================
# hundred.app
# =============================================

resource "cloudflare_dns_record" "beta" {
  zone_id = cloudflare_zone.hundred_app.id
  name    = "beta.hundred.app"
  type    = "A"
  content = upcloud_server.vps.network_interface[0].ip_address
  ttl     = 300
  proxied = false
}

resource "cloudflare_dns_record" "cname_16873660" {
  content = "sendgrid.net"
  name    = "16873660.hundred.app"
  proxied = false
  settings = {
    flatten_cname = false
    ipv4_only     = false
    ipv6_only     = false
  }
  ttl     = 1
  type    = "CNAME"
  zone_id = cloudflare_zone.hundred_app.id
}

resource "cloudflare_dns_record" "txt_asuid" {
  content = "8DF3E70F216CE650743E013FB970AAD6FA2A937187C91528D138E5EBA168AAB5"
  name    = "asuid.hundred.app"
  proxied = false
  ttl     = 1
  type    = "TXT"
  zone_id = cloudflare_zone.hundred_app.id
}

resource "cloudflare_dns_record" "a_apex" {
  content = "13.69.228.7"
  name    = "hundred.app"
  proxied = true
  ttl     = 1
  type    = "A"
  zone_id = cloudflare_zone.hundred_app.id
}

resource "cloudflare_dns_record" "cname_s1_domainkey" {
  content = "s1.domainkey.u10267722.wl223.sendgrid.net"
  name    = "s1._domainkey.hundred.app"
  proxied = false
  settings = {
    flatten_cname = false
    ipv4_only     = false
    ipv6_only     = false
  }
  ttl     = 1
  type    = "CNAME"
  zone_id = cloudflare_zone.hundred_app.id
}

resource "cloudflare_dns_record" "cname_em7430" {
  content = "u16873660.wl161.sendgrid.net"
  name    = "em7430.hundred.app"
  proxied = false
  settings = {
    flatten_cname = false
    ipv4_only     = false
    ipv6_only     = false
  }
  ttl     = 1
  type    = "CNAME"
  zone_id = cloudflare_zone.hundred_app.id
}

resource "cloudflare_dns_record" "cname_em4818" {
  content = "u10267722.wl223.sendgrid.net"
  name    = "em4818.hundred.app"
  proxied = false
  settings = {
    flatten_cname = false
    ipv4_only     = false
    ipv6_only     = false
  }
  ttl     = 1
  type    = "CNAME"
  zone_id = cloudflare_zone.hundred_app.id
}

resource "cloudflare_dns_record" "txt_dmarc" {
  content = "v=DMARC1; p=none;"
  name    = "_dmarc.hundred.app"
  proxied = false
  ttl     = 1
  type    = "TXT"
  zone_id = cloudflare_zone.hundred_app.id
}

resource "cloudflare_dns_record" "a_www" {
  content = "13.69.228.7"
  name    = "www.hundred.app"
  proxied = true
  ttl     = 1
  type    = "A"
  zone_id = cloudflare_zone.hundred_app.id
}

resource "cloudflare_dns_record" "cname_s2_domainkey" {
  content = "s2.domainkey.u10267722.wl223.sendgrid.net"
  name    = "s2._domainkey.hundred.app"
  proxied = false
  settings = {
    flatten_cname = false
    ipv4_only     = false
    ipv6_only     = false
  }
  ttl     = 1
  type    = "CNAME"
  zone_id = cloudflare_zone.hundred_app.id
}

resource "cloudflare_dns_record" "cname_url4710" {
  content = "sendgrid.net"
  name    = "url4710.hundred.app"
  proxied = false
  settings = {
    flatten_cname = false
    ipv4_only     = false
    ipv6_only     = false
  }
  ttl     = 1
  type    = "CNAME"
  zone_id = cloudflare_zone.hundred_app.id
}

resource "cloudflare_dns_record" "txt_apex" {
  content = "v=spf1 include:_spf.mx.cloudflare.net ~all"
  name    = "hundred.app"
  proxied = false
  ttl     = 1
  type    = "TXT"
  zone_id = cloudflare_zone.hundred_app.id
}
