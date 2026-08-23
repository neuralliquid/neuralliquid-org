data "cloudflare_zone" "neuralliquid" {
  filter = {
    name = var.dns_zone_name
  }
}

locals {
  zone_id = data.cloudflare_zone.neuralliquid.id

  # Mirrors infra/terraform/dns's product_cnames map — same live hosts, now
  # declared against the Cloudflare zone instead of the Azure one. Every
  # record here MUST stay unproxied (proxied = false): the origins are
  # Azure PaaS services validated via dns-txt-token / cname-delegation and
  # managed TLS, which depend on Cloudflare resolving straight through
  # (grey cloud). See docs/plans/azure-subscription-migration-plan.md,
  # Subtask 3, "Cloudflare zone built and verified" section.
  product_cnames = {
    convolens = {
      name = "convolens"
      # Corrected 2026-08-19 -> 2026-08-21: this had been declared without
      # the `-nl` suffix, matching infra/terraform/dns/main.tf and
      # docs/inventory/dns.md, but a direct `nslookup -type=CNAME
      # convolens.neuralliquid.ai` on 2026-08-21 confirmed the live target
      # carries the suffix. Live is correct; this file was wrong. Do not
      # revert toward the no-suffix value — same pattern as `hov_login`
      # below.
      record = "nl-prod-convolens-web-nl.azurewebsites.net"
      ttl    = 300
    }
    omnipost = {
      name   = "omnipost"
      record = "nl-dev-omnipost-web.azurewebsites.net"
      ttl    = 3600
    }
    cognitive_mesh = {
      name   = "cognitive-mesh"
      record = "cognitive-mesh-frontend-prod.azurewebsites.net"
      ttl    = 300
    }
    cognitive_mesh_control = {
      name   = "control.cognitive-mesh"
      record = "cognitive-mesh-frontend-prod.azurewebsites.net"
      ttl    = 300
    }
    cognitive_mesh_api = {
      name   = "api.cognitivemesh"
      record = "cognitive-mesh-api-prod.azurewebsites.net"
      ttl    = 300
    }
    hov = {
      name   = "hov"
      record = "nl-prod-hov-app.azurewebsites.net"
      ttl    = 300
    }
    hov_login = {
      name = "login.hov"
      # Container App, not an App Service — same live value corrected in
      # infra/terraform/dns/main.tf on 2026-08-19 (commit 5abc065 had
      # repointed this host without the Terraform ever being updated).
      record = "mys-prod-identity-api.politeocean-781513ae.southafricanorth.azurecontainerapps.io"
      ttl    = 300
    }
  }

  app_service_validation_records = {
    convolens = {
      name  = "asuid.convolens"
      ttl   = 300
      value = var.app_service_verification_id
    }
    omnipost = {
      name  = "asuid.omnipost"
      ttl   = 300
      value = var.app_service_verification_id
    }
    cognitive_mesh = {
      name  = "asuid.cognitive-mesh"
      ttl   = 300
      value = var.app_service_verification_id
    }
    cognitive_mesh_control = {
      name  = "asuid.control.cognitive-mesh"
      ttl   = 3600
      value = var.app_service_verification_id
    }
    cognitive_mesh_api = {
      name  = "asuid.api.cognitivemesh"
      ttl   = 300
      value = var.app_service_verification_id
    }
    hov = {
      name  = "asuid.hov"
      ttl   = 3600
      value = var.app_service_verification_id
    }
    hov_login = {
      name  = "asuid.login.hov"
      ttl   = 300
      value = var.mystira_identity_app_service_verification_id
    }
    github_enterprise_celladore = {
      name  = "_gh-celladoresystems-e"
      ttl   = 300
      value = "4bd016250d"
    }
  }

  # Cloudflare's flat record model needs one MX row per exchange, unlike
  # azurerm_dns_mx_record's single resource with multiple `record` blocks.
  mx_records = {
    mxa = {
      exchange   = "mxa.eu.mailgun.org"
      preference = 10
    }
    mxb = {
      exchange   = "mxb.eu.mailgun.org"
      preference = 10
    }
  }

  # Same flattening for the apex TXT set (dns-txt-token, SPF, OpenAI
  # verification) — Cloudflare has no multi-value TXT resource.
  apex_txt_records = {
    swa_domain_verification = {
      # Static Web App apex custom-domain ownership token (dns-txt-token
      # validation, see infra/terraform/web/main.tf
      # azurerm_static_web_app_custom_domain.apex).
      # 2026-08-21: updated for neuralliquid-web-prod on neuralliquid-sub.
      value = "_ub7jlhdju43c8axizuupylc00sg57mi"
    }
    mailgun_spf = {
      value = "v=spf1 include:mailgun.org ~all"
    }
    openai_verification = {
      value = "openai-domain-verification=dv-0edZSJrfP6PSNxukfE8qSj8y"
    }
  }
}

resource "cloudflare_dns_record" "product" {
  for_each = local.product_cnames

  zone_id = local.zone_id
  name    = each.value.name
  type    = "CNAME"
  content = each.value.record
  ttl     = each.value.ttl
  proxied = false
}

resource "cloudflare_dns_record" "app_service_validation" {
  for_each = local.app_service_validation_records

  zone_id = local.zone_id
  name    = each.value.name
  type    = "TXT"
  content = each.value.value
  ttl     = each.value.ttl
}

# Apex-level records. Added 2026-08-19 alongside the Cloudflare cutover —
# these existed as unmanaged/manual records before this migration and are
# now IaC-owned here, matching infra/terraform/dns/main.tf's apex block
# (kept there too as the verified rollback record set).

resource "cloudflare_dns_record" "apex_a" {
  zone_id = local.zone_id
  name    = "@"
  type    = "A"
  # Azure Static Web Apps apex custom-domain front-door IP for
  # nl-prod-web-swa (infra/terraform/web) — same value as the Azure zone.
  content = "9.163.40.246"
  ttl     = 3600
  proxied = false
}

resource "cloudflare_dns_record" "apex_mx" {
  for_each = local.mx_records

  zone_id  = local.zone_id
  name     = "@"
  type     = "MX"
  content  = each.value.exchange
  priority = each.value.preference
  ttl      = 3600
}

resource "cloudflare_dns_record" "apex_txt" {
  for_each = local.apex_txt_records

  zone_id = local.zone_id
  name    = "@"
  type    = "TXT"
  content = each.value.value
  ttl     = 3600
}

resource "cloudflare_dns_record" "www" {
  zone_id = local.zone_id
  name    = "www"
  type    = "CNAME"
  # neuralliquid-web-prod's default hostname (infra/terraform/web) — cname-delegation
  # validated custom domain, same Static Web App the apex A record serves.
  # 2026-08-21: updated for neuralliquid-web-prod on neuralliquid-sub.
  content = "black-plant-0aaf54b0f.7.azurestaticapps.net"
  ttl     = 3600
  proxied = false
}

resource "cloudflare_dns_record" "email" {
  zone_id = local.zone_id
  name    = "email"
  type    = "CNAME"
  # Mailgun tracking/open-tracking subdomain.
  content = "eu.mailgun.org"
  ttl     = 3600
  proxied = false
}
