# 2026-08-21: Subscription ID updated to 5a95ddee-dd63-441a-8306-c8b0803dcdd4 (neuralliquid-sub).
# House of Veritas (HOV) is strictly excluded per ADR 0004 and task 37547ca3 (HOV resides
# in nexamesh-sub / nex-prod-hov-rg; HOV database on mystira-sub is untouched).
#
# When reconstituting this stack in neuralliquid-sub:
# - If creating greenfield via `terraform apply`, these import blocks can be commented out
#   or removed once state is initialized.
# - If resources are pre-provisioned via `az` CLI, these import blocks allow `terraform apply`
#   to adopt them cleanly without duplicate creation errors.

import {
  to = azurerm_resource_group.shared
  id = "/subscriptions/5a95ddee-dd63-441a-8306-c8b0803dcdd4/resourceGroups/nl-prod-shared-rg"
}

import {
  to = azurerm_postgresql_flexible_server.shared
  id = "/subscriptions/5a95ddee-dd63-441a-8306-c8b0803dcdd4/resourceGroups/nl-prod-shared-rg/providers/Microsoft.DBforPostgreSQL/flexibleServers/nl-prod-data-pg"
}

import {
  to = azurerm_postgresql_flexible_server_database.tenant["convolens"]
  id = "/subscriptions/5a95ddee-dd63-441a-8306-c8b0803dcdd4/resourceGroups/nl-prod-shared-rg/providers/Microsoft.DBforPostgreSQL/flexibleServers/nl-prod-data-pg/databases/convolens"
}

import {
  to = azurerm_postgresql_flexible_server_firewall_rule.allow_azure_services
  id = "/subscriptions/5a95ddee-dd63-441a-8306-c8b0803dcdd4/resourceGroups/nl-prod-shared-rg/providers/Microsoft.DBforPostgreSQL/flexibleServers/nl-prod-data-pg/firewallRules/AllowAllAzureServicesAndResourcesWithinAzureIps_2026-8-7_2-56-48"
}

import {
  to = azurerm_postgresql_flexible_server_configuration.require_secure_transport
  id = "/subscriptions/5a95ddee-dd63-441a-8306-c8b0803dcdd4/resourceGroups/nl-prod-shared-rg/providers/Microsoft.DBforPostgreSQL/flexibleServers/nl-prod-data-pg/configurations/require_secure_transport"
}

import {
  to = azurerm_postgresql_flexible_server_configuration.ssl_min_protocol_version
  id = "/subscriptions/5a95ddee-dd63-441a-8306-c8b0803dcdd4/resourceGroups/nl-prod-shared-rg/providers/Microsoft.DBforPostgreSQL/flexibleServers/nl-prod-data-pg/configurations/ssl_min_protocol_version"
}

