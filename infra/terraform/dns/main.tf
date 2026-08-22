data "azurerm_dns_zone" "neuralliquid" {
  name                = var.dns_zone_name
  resource_group_name = var.dns_zone_resource_group
}

locals {
  product_cnames = {
    convolens = {
      name = "convolens"
      # Corrected 2026-08-19 -> 2026-08-21: this had been declared without
      # the `-nl` suffix, matching infra/terraform/dns-cloudflare/main.tf
      # and docs/inventory/dns.md, but a direct `nslookup -type=CNAME
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
      # 2026-08-19: corrected to match live reality, confirmed by direct
      # nslookup against the zone's authoritative nameservers. The old value
      # (mys-dev-id-webapi.azurewebsites.net, a dev App Service) was stale —
      # commit 5abc065 ("route HOV login to Mystira Identity") repointed this
      # host at a Container App and this file was never updated to match, and
      # no import block existed for it either (see imports.tf). Do not revert
      # this toward the old value; live is correct, this file was wrong.
      record = "mys-prod-identity-api.politeocean-781513ae.southafricanorth.azurecontainerapps.io"
      ttl    = 300
    }
  }

  app_service_validation_records = {
    convolens = {
      name            = "asuid.convolens"
      ttl             = 300
      verification_id = var.app_service_verification_id
    }
    omnipost = {
      name            = "asuid.omnipost"
      ttl             = 300
      verification_id = var.app_service_verification_id
    }
    cognitive_mesh = {
      name            = "asuid.cognitive-mesh"
      ttl             = 300
      verification_id = var.app_service_verification_id
    }
    cognitive_mesh_control = {
      name            = "asuid.control.cognitive-mesh"
      ttl             = 3600
      verification_id = var.app_service_verification_id
    }
    cognitive_mesh_api = {
      name            = "asuid.api.cognitivemesh"
      ttl             = 300
      verification_id = var.app_service_verification_id
    }
    hov = {
      name            = "asuid.hov"
      ttl             = 3600
      verification_id = var.app_service_verification_id
    }
    hov_login = {
      name            = "asuid.login.hov"
      ttl             = 300
      verification_id = var.mystira_identity_app_service_verification_id
    }
  }
}

resource "azurerm_dns_cname_record" "product" {
  for_each = local.product_cnames

  name                = each.value.name
  zone_name           = data.azurerm_dns_zone.neuralliquid.name
  resource_group_name = var.dns_zone_resource_group
  ttl                 = each.value.ttl
  record              = each.value.record
}

resource "azurerm_dns_txt_record" "app_service_validation" {
  for_each = local.app_service_validation_records

  name                = each.value.name
  zone_name           = data.azurerm_dns_zone.neuralliquid.name
  resource_group_name = var.dns_zone_resource_group
  ttl                 = each.value.ttl

  record {
    value = each.value.verification_id
  }
}

# Apex-level records. Added 2026-08-19 during the org-wide DNS zone
# migration (docs/plans/azure-subscription-migration-plan.md, Track B) —
# these existed as unmanaged/manual records in the legacy zone and were
# never previously represented in this module. Values were captured live
# via nslookup immediately before the new zone was built, so this is the
# first time they're IaC-owned rather than a design change.

resource "azurerm_dns_a_record" "apex" {
  name                = "@"
  zone_name           = data.azurerm_dns_zone.neuralliquid.name
  resource_group_name = var.dns_zone_resource_group
  ttl                 = 3600
  # Azure Static Web Apps apex custom-domain front-door IP for nl-prod-web-swa
  # (infra/terraform/web) — not tied to a particular subscription, safe to
  # carry forward verbatim. This is a DIFFERENT Static Web App than
  # neuralliquid-web-prod; see PRD open decision on apex-vs-subdomain.
  records = ["9.163.40.246"]
}

resource "azurerm_dns_mx_record" "apex" {
  name                = "@"
  zone_name           = data.azurerm_dns_zone.neuralliquid.name
  resource_group_name = var.dns_zone_resource_group
  ttl                 = 3600

  record {
    preference = 10
    exchange   = "mxa.eu.mailgun.org"
  }
  record {
    preference = 10
    exchange   = "mxb.eu.mailgun.org"
  }
}

resource "azurerm_dns_txt_record" "apex" {
  name                = "@"
  zone_name           = data.azurerm_dns_zone.neuralliquid.name
  resource_group_name = var.dns_zone_resource_group
  ttl                 = 3600

  # Static Web App apex custom-domain ownership token (dns-txt-token
  # validation, see infra/terraform/web/main.tf azurerm_static_web_app_custom_domain.apex).
  # 2026-08-21: updated for neuralliquid-web-prod on neuralliquid-sub.
  record {
    value = "_1qttf197b2q97b4za18sylxn8amz1a6"
  }
  # SPF for Mailgun.
  record {
    value = "v=spf1 include:mailgun.org ~all"
  }
  # OpenAI domain ownership verification.
  record {
    value = "openai-domain-verification=dv-0edZSJrfP6PSNxukfE8qSj8y"
  }
}

resource "azurerm_dns_cname_record" "www" {
  name                = "www"
  zone_name           = data.azurerm_dns_zone.neuralliquid.name
  resource_group_name = var.dns_zone_resource_group
  ttl                 = 3600
  # neuralliquid-web-prod's default hostname (infra/terraform/web) — cname-delegation
  # validated custom domain, same Static Web App the apex A record serves.
  # 2026-08-21: updated for neuralliquid-web-prod on neuralliquid-sub.
  record = "black-plant-0aaf54b0f.7.azurestaticapps.net"
}

resource "azurerm_dns_cname_record" "email" {
  name                = "email"
  zone_name           = data.azurerm_dns_zone.neuralliquid.name
  resource_group_name = var.dns_zone_resource_group
  ttl                 = 3600
  # Mailgun tracking/open-tracking subdomain.
  record = "eu.mailgun.org"
}
