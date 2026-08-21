variable "subscription_id" {
  type        = string
  description = "Azure subscription for NeuralLiquid org control-plane state."
  default     = "5a95ddee-dd63-441a-8306-c8b0803dcdd4"
}

variable "location" {
  type        = string
  description = "Azure region for the Terraform state resource group."
  default     = "southafricanorth"
}

variable "resource_group_name" {
  type        = string
  description = "Resource group for NeuralLiquid org Terraform state."
  default     = "nl-org-tfstate-rg"
}

variable "storage_account_name" {
  type        = string
  description = "Globally unique storage account name for NeuralLiquid org Terraform state."
  default     = "nlorgtfstate"
}

variable "container_name" {
  type        = string
  description = "Blob container for Terraform state files."
  default     = "tfstate"
}
