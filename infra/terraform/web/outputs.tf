output "static_web_app_id" {
  description = "Resource ID of the managed Static Web App."
  value       = azapi_resource.site.id
}

output "default_host_name" {
  description = "Azure-provided hostname."
  value       = azapi_resource.site.output.properties.defaultHostname
}
