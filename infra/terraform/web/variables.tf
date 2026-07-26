variable "subscription_id" {
  type        = string
  description = "Azure subscription containing the NeuralLiquid production website."
  default     = "bb4e3882-2079-4bab-8974-611bc0b8bb58"
}

variable "resource_group_name" {
  type        = string
  description = "Existing resource group containing the Static Web App."
  default     = "nl-prod-web-rg"
}

variable "static_web_app_name" {
  type        = string
  description = "Existing production Static Web App name."
  default     = "nl-prod-web-swa"
}

variable "location" {
  type        = string
  description = "Existing Static Web App location."
  default     = "West Europe"
}

variable "github_oidc_principal_object_id" {
  type        = string
  description = "Object ID of the existing nl-org-github-actions service principal."
  default     = "369def47-8d91-4710-8c37-e521bc4a360a"
}
