variable "subscription_id" {
  type        = string
  description = "Azure subscription that contains the shared NeuralLiquid data plane."
  default     = "bb4e3882-2079-4bab-8974-611bc0b8bb58"
}

variable "resource_group_name" {
  type        = string
  description = "Resource group holding org-owned shared data resources."
  default     = "nl-prod-shared-rg"
}

variable "location" {
  type        = string
  description = "Azure region. South Africa North for POPIA data residency."
  default     = "southafricanorth"
}

variable "server_name" {
  type        = string
  description = "Shared PostgreSQL Flexible Server name."
  default     = "nl-prod-shared-pg"
}

variable "administrator_login" {
  type        = string
  description = "Server administrator login. Used for server-level operations only; no application connects as this role."
  default     = "nlsharedadmin"
}

variable "administrator_password" {
  type        = string
  description = <<-EOT
    Server administrator password, held at nl-prod-convolens-kv/shared-pg-admin-password
    pending relocation to an org-owned vault. Deliberately null by default so that
    plan and apply never require the secret: changes to this attribute are ignored on
    the existing server. Supply it out of band only if the server must be recreated.
  EOT
  sensitive   = true
  default     = null
}

variable "tenant_databases" {
  type        = map(string)
  description = "Databases on the shared server, keyed by owning product. The database is org-owned; its schema, roles and grants are owned by the product that uses it."
  default = {
    house_of_veritas = "houseofveritas"
    convolens        = "convolens"
  }
}
