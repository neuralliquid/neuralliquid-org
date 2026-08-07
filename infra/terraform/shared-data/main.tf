# Shared NeuralLiquid data plane.
#
# One PostgreSQL Flexible Server, one database and one scoped login role per
# product. The server, its resource group, its firewall and the database objects
# are org-owned. Everything inside a database — schema, roles, grants, migrations
# — is owned by the product that uses it.
#
# See docs/adr/0002-shared-data-plane-ownership.md.

locals {
  tags = {
    environment = "prod"
    project     = "neuralliquid-shared"
  }
}

resource "azurerm_resource_group" "shared" {
  name     = var.resource_group_name
  location = var.location

  tags = local.tags
}

resource "azurerm_postgresql_flexible_server" "shared" {
  name                = var.server_name
  resource_group_name = azurerm_resource_group.shared.name
  location            = azurerm_resource_group.shared.location
  version             = "16"
  zone                = "2"

  administrator_login    = var.administrator_login
  administrator_password = var.administrator_password

  # Burstable tier, Standard_B1ms. The provider prefixes the tier: B / GP / MO.
  sku_name          = "B_Standard_B1ms"
  storage_mb        = 32768
  storage_tier      = "P4"
  auto_grow_enabled = false

  backup_retention_days        = 7
  geo_redundant_backup_enabled = false

  # Access is by firewall rule, not private networking: the two tenant
  # applications reach the server over the Azure services allowance below.
  public_network_access_enabled = true

  tags = local.tags

  lifecycle {
    # The password is never held in this state or this repo; it lives in Key
    # Vault and is rotated out of band. high_availability is Azure-managed on a
    # Burstable tier and reports back a shape Terraform did not set.
    ignore_changes = [administrator_password, high_availability]
  }
}

# Tenant databases. Adding one here is the org-level act of granting a product a
# home on the shared server; the product then creates its own role and schema.
resource "azurerm_postgresql_flexible_server_database" "tenant" {
  for_each = var.tenant_databases

  name      = each.value
  server_id = azurerm_postgresql_flexible_server.shared.id
  charset   = "UTF8"
  collation = "en_US.utf8"

  lifecycle {
    # Dropping a tenant database must be a deliberate, out-of-band decision, not
    # a side effect of editing a map in this file.
    prevent_destroy = true
  }
}

# Permits Azure-hosted callers only — the HOV App Service and the Convolens
# container app. Developer access requires a temporary rule, added and removed
# per use. The name is Azure-generated from the portal action that created it;
# renaming it would destroy and recreate the rule, briefly cutting both
# applications off, so it is kept as-is.
resource "azurerm_postgresql_flexible_server_firewall_rule" "allow_azure_services" {
  name             = "AllowAllAzureServicesAndResourcesWithinAzureIps_2026-8-7_2-56-48"
  server_id        = azurerm_postgresql_flexible_server.shared.id
  start_ip_address = "0.0.0.0"
  end_ip_address   = "0.0.0.0"
}

# Both of these currently match the Azure system default. They are declared so
# that a future portal change, or an Azure default change, shows up as drift
# rather than passing unnoticed.
resource "azurerm_postgresql_flexible_server_configuration" "require_secure_transport" {
  name      = "require_secure_transport"
  server_id = azurerm_postgresql_flexible_server.shared.id
  value     = "on"
}

resource "azurerm_postgresql_flexible_server_configuration" "ssl_min_protocol_version" {
  name      = "ssl_min_protocol_version"
  server_id = azurerm_postgresql_flexible_server.shared.id
  value     = "TLSv1.2"
}
