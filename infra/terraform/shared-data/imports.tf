# Every resource in this stack already exists. It was created with `az` during
# the 2026-08-06 database consolidation and has been drift since. These blocks
# adopt it; nothing here should create anything.

import {
  to = azurerm_resource_group.shared
  id = "/subscriptions/bb4e3882-2079-4bab-8974-611bc0b8bb58/resourceGroups/nl-prod-shared-rg"
}

import {
  to = azurerm_postgresql_flexible_server.shared
  id = "/subscriptions/bb4e3882-2079-4bab-8974-611bc0b8bb58/resourceGroups/nl-prod-shared-rg/providers/Microsoft.DBforPostgreSQL/flexibleServers/nl-prod-shared-pg"
}

import {
  to = azurerm_postgresql_flexible_server_database.tenant["house_of_veritas"]
  id = "/subscriptions/bb4e3882-2079-4bab-8974-611bc0b8bb58/resourceGroups/nl-prod-shared-rg/providers/Microsoft.DBforPostgreSQL/flexibleServers/nl-prod-shared-pg/databases/houseofveritas"
}

import {
  to = azurerm_postgresql_flexible_server_database.tenant["convolens"]
  id = "/subscriptions/bb4e3882-2079-4bab-8974-611bc0b8bb58/resourceGroups/nl-prod-shared-rg/providers/Microsoft.DBforPostgreSQL/flexibleServers/nl-prod-shared-pg/databases/convolens"
}

import {
  to = azurerm_postgresql_flexible_server_firewall_rule.allow_azure_services
  id = "/subscriptions/bb4e3882-2079-4bab-8974-611bc0b8bb58/resourceGroups/nl-prod-shared-rg/providers/Microsoft.DBforPostgreSQL/flexibleServers/nl-prod-shared-pg/firewallRules/AllowAllAzureServicesAndResourcesWithinAzureIps_2026-8-7_2-56-48"
}

import {
  to = azurerm_postgresql_flexible_server_configuration.require_secure_transport
  id = "/subscriptions/bb4e3882-2079-4bab-8974-611bc0b8bb58/resourceGroups/nl-prod-shared-rg/providers/Microsoft.DBforPostgreSQL/flexibleServers/nl-prod-shared-pg/configurations/require_secure_transport"
}

import {
  to = azurerm_postgresql_flexible_server_configuration.ssl_min_protocol_version
  id = "/subscriptions/bb4e3882-2079-4bab-8974-611bc0b8bb58/resourceGroups/nl-prod-shared-rg/providers/Microsoft.DBforPostgreSQL/flexibleServers/nl-prod-shared-pg/configurations/ssl_min_protocol_version"
}
