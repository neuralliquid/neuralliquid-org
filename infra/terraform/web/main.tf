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
# Define the role at resource-group scope, but assign its two read operations
# only at the one production site.
resource "azurerm_role_definition" "static_web_app_deployer" {
  name               = "NeuralLiquid Static Web App Deployment Token Reader"
  role_definition_id = "4f2e91ee-f832-45a4-a4d2-9f18dbc5c514"
  scope              = local.resource_group_id

  description = "Reads the NeuralLiquid production Static Web App deployment token for ephemeral CI deployment."

  permissions {
    actions = [
      "Microsoft.Web/staticSites/listSecrets/action",
      "Microsoft.Web/staticSites/read",
    ]
    not_actions = []
  }

  assignable_scopes = [local.resource_group_id]
}

resource "azurerm_role_assignment" "github_oidc_static_web_app_deployer" {
  scope              = azapi_resource.site.id
  role_definition_id = azurerm_role_definition.static_web_app_deployer.role_definition_resource_id
  principal_id       = var.github_oidc_principal_object_id
  principal_type     = "ServicePrincipal"
}
