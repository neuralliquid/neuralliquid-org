terraform {
  backend "azurerm" {
    subscription_id      = "5a95ddee-dd63-441a-8306-c8b0803dcdd4"
    resource_group_name  = "nl-org-tfstate-rg"
    storage_account_name = "nlorgtfstatesa"
    container_name       = "tfstate"
    key                  = "dns/terraform.tfstate"
    use_azuread_auth     = true
  }
}
