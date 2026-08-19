# Targets the same remote-state storage account the rest of neuralliquid-org
# Terraform uses (infra/terraform/bootstrap/tfstate), with a stack-specific
# key so it doesn't collide with infra/terraform/dns's state.
#
# 2026-08-19: this storage account does not exist yet — Subtask 2 of
# docs/plans/azure-subscription-migration-plan.md ("NeuralLiquid Azure
# Subscription & OIDC Federation Setup") provisions it. Until then,
# `terraform init` here fails the same way infra/terraform/dns's does.
# Use `terraform init -backend=false` for validation only until the
# bootstrap stack has been applied.
terraform {
  backend "azurerm" {
    subscription_id      = "5a95ddee-dd63-441a-8306-c8b0803dcdd4"
    resource_group_name  = "nl-org-tfstate-rg"
    storage_account_name = "nlorgtfstate"
    container_name       = "tfstate"
    key                  = "dns-cloudflare/terraform.tfstate"
    use_azuread_auth     = true
  }
}
