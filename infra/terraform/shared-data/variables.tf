variable "subscription_id" {
  type        = string
  description = "Azure subscription that contains the shared NeuralLiquid data plane."
  default     = "5a95ddee-dd63-441a-8306-c8b0803dcdd4"
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
  description = "Shared PostgreSQL Flexible Server name in neuralliquid-sub."
  default     = "nl-prod-data-pg"
}

variable "administrator_login" {
  type        = string
  description = "Server administrator login. Used for server-level operations only; no application connects as this role."
  default     = "nlsharedadmin"
}

variable "administrator_password" {
  type        = string
  description = <<-EOT
    Server administrator password, held at nl-prod-shared-kv/postgres-admin-password.
    Consumed as a write-only attribute, so it is never written to state. Null by
    default: a plan needs no secret, and neither does an apply that changes nothing
    on the server itself. Supply it, with administrator_password_wo_version, for any
    apply that does. No application connects as this role.
  EOT
  sensitive   = true
  default     = null
}

variable "administrator_password_wo_version" {
  type        = number
  description = <<-EOT
    Version counter for the write-only password. The provider requires it and
    administrator_password to be set together, so both stay null for routine work
    and are supplied as a pair when the credential genuinely needs to be sent.
  EOT
  default     = null
}

variable "key_vault_name" {
  type        = string
  description = "Org-owned vault for shared data plane credentials."
  default     = "nl-prod-shared-kv"
}

variable "key_vault_role_assignments" {
  type = map(object({
    role         = string
    principal_id = string
  }))
  description = <<-EOT
    RBAC assignments on the shared vault, keyed by a stable label. This vault uses
    RBAC, so subscription Owner alone does not grant data-plane access — a secrets
    role must be assigned explicitly, per vault, which matches how nl-prod-convolens-kv
    and nl-dev-omnipost-kv are already granted. Operators need "Key Vault Secrets
    Officer"; a workload that only reads needs "Key Vault Secrets User".

    Object IDs are directory identifiers, not secrets, and belong in review.
  EOT
  default = {
    operator_jurie = {
      role         = "Key Vault Secrets Officer"
      principal_id = "99b63adb-8f1a-4d7a-a98c-5bfe9c7fcd96"
    }
  }
}

variable "tenant_databases" {
  type        = map(string)
  description = <<-EOT
    Databases on the shared server, keyed by owning product. The database is org-owned;
    its schema, roles and grants are owned by the product that uses it.

    NOTE: House of Veritas (HOV) is strictly excluded per ADR 0004 and Baton task
    37547ca3. HOV is classified as a NexaMesh physical-estate product and its data
    resides on an isolated datastore in nex-prod-hov-rg under nexamesh-sub. HOV data
    on mystira-sub remains untouched until its separate, independently authorized migration.
  EOT
  default = {
    convolens = "convolens"
  }
}

