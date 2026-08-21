variable "subscription_id" {
  type        = string
  description = "Azure subscription that contains the neuralliquid.ai DNS zone (neuralliquid-sub)."
  default     = "5a95ddee-dd63-441a-8306-c8b0803dcdd4"
}

variable "dns_zone_name" {
  type        = string
  description = "Authoritative NeuralLiquid DNS zone."
  default     = "neuralliquid.ai"
}

variable "dns_zone_resource_group" {
  type        = string
  description = "Resource group containing the NeuralLiquid DNS zone. 2026-08-19: nl-global-shared-rg in neuralliquid-sub (was mys-global-shared-rg in the legacy subscription) — see subscription_id."
  default     = "nl-global-shared-rg"
}

variable "app_service_verification_id" {
  type        = string
  description = "Shared App Service custom domain verification ID currently used by NeuralLiquid App Services."
  default     = "05B038A75C9A9151C1E0ECF5F652F255707230C7408A56A6686F15CA9CDA6872"
}

variable "mystira_identity_app_service_verification_id" {
  type        = string
  description = "Custom-domain verification ID for the Mystira Identity App Service used by login.hov. Its default is byte-identical to app_service_verification_id's — unverified whether that's because both App Services genuinely share one verification ID, or a copy-paste inherited across this repo's stacks. Kept as a separate variable so the two can diverge without a code change once verified; do not assume the shared default is correct without checking the live TXT record."
  default     = "05B038A75C9A9151C1E0ECF5F652F255707230C7408A56A6686F15CA9CDA6872"

  validation {
    condition     = length(trimspace(var.mystira_identity_app_service_verification_id)) > 0
    error_message = "mystira_identity_app_service_verification_id must not be empty."
  }
}
