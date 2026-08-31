# Shared NeuralLiquid data plane.
#
# One PostgreSQL Flexible Server, one database and one scoped login role per
# product. The server, its resource group, its firewall and the database objects
# are org-owned. Everything inside a database — schema, roles, grants, migrations
# — is owned by the product that uses it.
#
# See docs/adr/0002-shared-data-plane-ownership.md.

data "azurerm_client_config" "current" {}

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

resource "random_password" "postgres_admin" {
  length           = 32
  special          = true
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

resource "azurerm_postgresql_flexible_server" "shared" {
  name                = var.server_name
  resource_group_name = azurerm_resource_group.shared.name
  location            = azurerm_resource_group.shared.location
  version             = "16"
  zone                = "2"

  administrator_login               = var.administrator_login
  administrator_password_wo         = coalesce(var.administrator_password, random_password.postgres_admin.result)
  administrator_password_wo_version = 1

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
    # high_availability is Azure-managed on a Burstable tier and reports back a
    # shape Terraform did not set.
    #
    ignore_changes = [high_availability]
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

# Azure-managed sentinel firewall rule (0.0.0.0/0.0.0.0) imported from live configuration.
# Permits Azure-hosted callers — currently the Convolens tenant runtime in neuralliquid-sub;
# Tarmac's runtime will reach the server the same way once its own onboarding lands.
# The `convolens` and `tarmac` tenant databases are declared on this server; `tarmac`'s
# database exists once this stack applies, but its role/schema/PUBLIC-CONNECT-revoke are
# still pending (see the shared-data README's "Onboarding a Tenant" steps 2–4).
#
# COMPENSATING SECURITY CONTROLS:
# 1. Tenant Isolation: Default PUBLIC CONNECT is revoked on each tenant database as part of
#    tenant onboarding (`convolens` revoked 2026-08-07 via `REVOKE CONNECT ON DATABASE convolens
#    FROM PUBLIC`; `tarmac` pending onboarding step 3), allowing only each tenant's own
#    authenticated role access once revoked.
# 2. Encryption: Forced TLS 1.2+ (`ssl_min_protocol_version = "TLSv1.2"`) and `require_secure_transport = "ON"`.
# 3. Authentication: SCRAM-SHA-256 hashed strong credentials stored in Key Vault.
# 4. Roadmap: Migration to private endpoints / delegated VNet subnet once Container Apps VNet integration is provisioned.
resource "azurerm_postgresql_flexible_server_firewall_rule" "allow_azure_services" {
  name             = "AllowAllAzureServicesAndResourcesWithinAzureIps_2026-8-7_2-56-48"
  server_id        = azurerm_postgresql_flexible_server.shared.id
  start_ip_address = "0.0.0.0"
  end_ip_address   = "0.0.0.0"
}


# Org-owned credential store for the shared data plane. It holds secrets that
# belong to the server rather than to any one tenant — today, the server admin
# password. A tenant's own connection string does not belong here; it belongs in
# that product's vault.
resource "azurerm_key_vault" "shared" {
  name                = var.key_vault_name
  resource_group_name = azurerm_resource_group.shared.name
  location            = azurerm_resource_group.shared.location
  tenant_id           = data.azurerm_client_config.current.tenant_id
  sku_name            = "standard"

  # RBAC rather than access policies. The older access-policy model is what
  # currently makes nl-prod-hov-kv awkward to administer.
  rbac_authorization_enabled = true

  soft_delete_retention_days = 90

  # Deliberately off. Purge protection cannot be switched back off once set, and
  # at this size the likelier accident is being unable to reuse a vault name for
  # 90 days, not a malicious purge. Revisit when the org has more than one
  # operator.
  purge_protection_enabled = false

  tags = local.tags
}

resource "azurerm_role_assignment" "key_vault" {
  for_each = var.key_vault_role_assignments

  scope                = azurerm_key_vault.shared.id
  role_definition_name = each.value.role
  principal_id         = each.value.principal_id
}

resource "azurerm_key_vault_secret" "postgres_admin" {
  name         = "postgres-admin-password"
  value        = coalesce(var.administrator_password, random_password.postgres_admin.result)
  key_vault_id = azurerm_key_vault.shared.id

  depends_on = [
    azurerm_role_assignment.key_vault
  ]
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
