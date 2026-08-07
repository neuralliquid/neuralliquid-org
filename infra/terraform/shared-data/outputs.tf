output "server_name" {
  description = "Shared PostgreSQL Flexible Server name."
  value       = azurerm_postgresql_flexible_server.shared.name
}

output "server_fqdn" {
  description = "Host to use in product connection strings."
  value       = azurerm_postgresql_flexible_server.shared.fqdn
}

output "server_id" {
  description = "Resource ID, for product stacks that need to reference the server without owning it."
  value       = azurerm_postgresql_flexible_server.shared.id
}

output "tenant_databases" {
  description = "Database name per owning product."
  value       = { for product, db in azurerm_postgresql_flexible_server_database.tenant : product => db.name }
}
