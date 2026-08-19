variable "subscription_id" {
  type = string
  description = <<-EOT
    Azure subscription that contains the neuralliquid.ai DNS zone.
    2026-08-19: points at neuralliquid-sub, the zone recreated there during
    the org-wide DNS migration (docs/plans/azure-subscription-migration-plan.md,
    Track B). The old value (bb4e3882-2079-4bab-8974-611bc0b8bb58, the
    inaccessible legacy subscription) is left below for reference only.
    This module's backend.tf still points its remote state at that legacy
    subscription too, so `terraform plan/apply` cannot run here regardless
    of this value until that's bootstrapped — the live zone was built via
    `az` CLI directly. Old value: "bb4e3882-2079-4bab-8974-611bc0b8bb58"
  EOT
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
  description = "Independently sourced custom-domain verification ID for the Mystira Identity App Service used by login.hov."
  default     = "05B038A75C9A9151C1E0ECF5F652F255707230C7408A56A6686F15CA9CDA6872"

  validation {
    condition     = length(trimspace(var.mystira_identity_app_service_verification_id)) > 0
    error_message = "mystira_identity_app_service_verification_id must not be empty."
  }
}
