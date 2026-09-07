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

# Proxying would replace the client address with Cloudflare's, defeating tailnet
# source restrictions at the ingress.
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

resource "cloudflare_dns_record" "txt_cf2024_1_domainkey" {
  content = "\"v=DKIM1; h=sha256; k=rsa; p=MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAiweykoi+o48IOGuP7GR3X0MOExCUDY/BCRHoWBnh3rChl7WhdyCxW3jgq1daEjPPqoi7sJvdg5hEQVsgVRQP4DcnQDVjGMbASQtrY4WmB1VebF+RPJB2ECPsEDTpeiI5ZyUAwJaVX7r6bznU67g7LvFq35yIo4sdlmtZGV+i0H4cpYH9+3JJ78k\" \"m4KXwaf9xUJCWF6nxeD+qG6Fyruw1Qlbds2r85U9dkNDVAS3gioCvELryh1TxKGiVTkg4wqHTyHfWsp7KD3WQHYJn0RyfJJu6YEmL77zonn7p2SRMvTMP3ZEXibnC9gz3nnhR6wcYL8Q7zXypKTMD58bTixDSJwIDAQAB\""
  name    = "cf2024-1._domainkey.hundred.app"
  proxied = false
  ttl     = 1
  type    = "TXT"
  zone_id = cloudflare_zone.hundred_app.id
}

resource "cloudflare_dns_record" "cname_s1_domainkey" {
  content = "s1.domainkey.u16873660.wl161.sendgrid.net"
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

resource "cloudflare_dns_record" "a_www" {
  content = "13.69.228.7"
  name    = "www.hundred.app"
  proxied = true
  ttl     = 1
  type    = "A"
  zone_id = cloudflare_zone.hundred_app.id
}

resource "cloudflare_dns_record" "mx_apex_1" {
  content  = "route1.mx.cloudflare.net"
  name     = "hundred.app"
  priority = 16
  proxied  = false
  ttl      = 1
  type     = "MX"
  zone_id  = cloudflare_zone.hundred_app.id
}

resource "cloudflare_dns_record" "cname_s2_domainkey" {
  content = "s2.domainkey.u16873660.wl161.sendgrid.net"
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

resource "cloudflare_dns_record" "mx_apex_2" {
  content  = "route2.mx.cloudflare.net"
  name     = "hundred.app"
  priority = 84
  proxied  = false
  ttl      = 1
  type     = "MX"
  zone_id  = cloudflare_zone.hundred_app.id
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

resource "cloudflare_dns_record" "mx_apex_3" {
  content  = "route3.mx.cloudflare.net"
  name     = "hundred.app"
  priority = 6
  proxied  = false
  ttl      = 1
  type     = "MX"
  zone_id  = cloudflare_zone.hundred_app.id
}

resource "cloudflare_dns_record" "txt_apex" {
  content = "v=spf1 include:_spf.mx.cloudflare.net ~all"
  name    = "hundred.app"
  proxied = false
  ttl     = 1
  type    = "TXT"
  zone_id = cloudflare_zone.hundred_app.id
}
