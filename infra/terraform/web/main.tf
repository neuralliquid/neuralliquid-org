locals {
  resource_group_id = "/subscriptions/${var.subscription_id}/resourceGroups/${var.resource_group_name}"
}

# AzAPI deliberately owns the site: unlike azurerm_static_web_app it does not
# read the deployment API key into Terraform state.
resource "azapi_resource" "site" {
  type      = "Microsoft.Web/staticSites@2025-03-01"
  name      = var.static_web_app_name
  parent_id = local.resource_group_id
  location  = var.location

  body = {
    properties = {
      allowConfigFileUpdates   = true
      provider                 = "SwaCli"
      stagingEnvironmentPolicy = "Enabled"
    }
    sku = {
      name = "Free"
      tier = "Free"
    }
  }

  tags = {
    environment = "prod"
    managed-by  = "cli"
    project     = "neuralliquid"
    purpose     = "placeholder-website"
  }

  lifecycle {
    prevent_destroy = true
  }
}

resource "azurerm_static_web_app_custom_domain" "apex" {
  static_web_app_id = azapi_resource.site.id
  domain_name       = "neuralliquid.ai"
  validation_type   = "dns-txt-token"

  lifecycle {
    prevent_destroy = true
    ignore_changes  = [validation_type]
  }
}

resource "azurerm_static_web_app_custom_domain" "www" {
  static_web_app_id = azapi_resource.site.id
  domain_name       = "www.neuralliquid.ai"
  validation_type   = "cname-delegation"

  lifecycle {
    prevent_destroy = true
    ignore_changes  = [validation_type]
  }
}

# Azure has no built-in role limited to Static Web App deployment-token reads.
# The custom role and role assignment were bootstrapped out-of-band on
# 2026-08-21 and are not managed by this stack to avoid provider import
# limitations with azurerm_role_definition in this environment.
