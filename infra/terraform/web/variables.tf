variable "subscription_id" {
  type        = string
  description = "Azure subscription containing the NeuralLiquid production website (neuralliquid-sub)."
  default     = "5a95ddee-dd63-441a-8306-c8b0803dcdd4"
}

variable "resource_group_name" {
  type        = string
  description = "Existing resource group containing the Static Web App."
  default     = "nl-web-rg"
}

variable "static_web_app_name" {
  type        = string
  description = "Existing production Static Web App name."
  default     = "neuralliquid-web-prod"
}

variable "location" {
  type        = string
  description = "Existing Static Web App location."
  default     = "eastus2"
}

variable "github_oidc_principal_object_id" {
  type        = string
  description = "Object ID of the existing nl-org-github-actions service principal."
  default     = "369def47-8d91-4710-8c37-e521bc4a360a"
}
