variable "cloudflare_api_token" {
  type        = string
  sensitive   = true
  description = <<-EOT
    Scoped Cloudflare API token (Zone:DNS:Edit, restricted to the
    neuralliquid.ai zone only) used to manage this zone's records.
    Never commit a real value — supply via TF_VAR_cloudflare_api_token or
    a CI secret. See docs/plans/azure-subscription-migration-plan.md,
    Subtask 3, for how the current token was scoped when it was generated.
  EOT
}

variable "dns_zone_name" {
  type        = string
  description = "Authoritative NeuralLiquid DNS zone, now delegated to Cloudflare."
  default     = "neuralliquid.ai"
}

variable "app_service_verification_id" {
  type        = string
  description = "Shared App Service custom domain verification ID currently used by NeuralLiquid App Services. Same value as infra/terraform/dns's variable of the same name — both stacks describe the same live records, one per DNS host (Azure zone, kept as rollback reference; Cloudflare zone, the live delegation target)."
  default     = "05B038A75C9A9151C1E0ECF5F652F255707230C7408A56A6686F15CA9CDA6872"
}

variable "mystira_identity_app_service_verification_id" {
  type        = string
  description = "Custom-domain verification ID for the Mystira Identity App Service used by login.hov. Its default is byte-identical to app_service_verification_id's — unverified whether that's because both App Services genuinely share one verification ID, or a copy-paste this stack inherited from infra/terraform/dns. Kept as a separate variable so the two can diverge without a code change once verified; do not assume the shared default is correct without checking the live TXT record."
  default     = "05B038A75C9A9151C1E0ECF5F652F255707230C7408A56A6686F15CA9CDA6872"

  validation {
    condition     = length(trimspace(var.mystira_identity_app_service_verification_id)) > 0
    error_message = "mystira_identity_app_service_verification_id must not be empty."
  }
}
