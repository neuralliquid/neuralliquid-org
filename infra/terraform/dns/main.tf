data "azurerm_dns_zone" "neuralliquid" {
  name                = var.dns_zone_name
  resource_group_name = var.dns_zone_resource_group
}

locals {
  product_cnames = {
    convolens = {
      name   = "convolens"
      record = "nl-prod-convolens-web.azurewebsites.net"
      ttl    = 300
    }
    omnipost = {
      name   = "omnipost"
      record = "neuralliquid.ai"
      ttl    = 300
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
  }

  app_service_validation_records = {
    convolens = {
      name = "asuid.convolens"
      ttl  = 300
    }
    cognitive_mesh = {
      name = "asuid.cognitive-mesh"
      ttl  = 300
    }
    cognitive_mesh_control = {
      name = "asuid.control.cognitive-mesh"
      ttl  = 3600
    }
    cognitive_mesh_api = {
      name = "asuid.api.cognitivemesh"
      ttl  = 300
    }
    hov = {
      name = "asuid.hov"
      ttl  = 3600
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
    value = var.app_service_verification_id
  }
}
