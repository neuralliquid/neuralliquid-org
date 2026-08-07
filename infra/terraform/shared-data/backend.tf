terraform {
  backend "azurerm" {
    subscription_id      = "bb4e3882-2079-4bab-8974-611bc0b8bb58"
    resource_group_name  = "nl-org-tfstate-rg"
    storage_account_name = "nlorgtfstate"
    container_name       = "tfstate"
    key                  = "shared-data/terraform.tfstate"
    use_azuread_auth     = true
  }
}
