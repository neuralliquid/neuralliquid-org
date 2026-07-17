variable "subscription_id" {
  type        = string
  description = "Azure subscription that contains the neuralliquid.ai DNS zone."
  default     = "bb4e3882-2079-4bab-8974-611bc0b8bb58"
}

variable "dns_zone_name" {
  type        = string
  description = "Authoritative NeuralLiquid DNS zone."
  default     = "neuralliquid.ai"
}

variable "dns_zone_resource_group" {
  type        = string
  description = "Resource group containing the NeuralLiquid DNS zone."
  default     = "mys-global-shared-rg"
}

variable "app_service_verification_id" {
  type        = string
  description = "Shared App Service custom domain verification ID currently used by NeuralLiquid App Services."
  default     = "05B038A75C9A9151C1E0ECF5F652F255707230C7408A56A6686F15CA9CDA6872"
}
