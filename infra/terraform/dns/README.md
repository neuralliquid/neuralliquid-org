# DNS Terraform

This stack owns NeuralLiquid product DNS records in the existing Azure DNS zone:

- zone: `neuralliquid.ai`
- resource group: `mys-global-shared-rg`
- subscription: `bb4e3882-2079-4bab-8974-611bc0b8bb58`

The zone itself is read as a data source. Product records are managed here.

## Current Scope

- `convolens.neuralliquid.ai`
- `omnipost.neuralliquid.ai`
- `cognitive-mesh.neuralliquid.ai`
- `control.cognitive-mesh.neuralliquid.ai`
- `api.cognitivemesh.neuralliquid.ai`
- `hov.neuralliquid.ai`
- `login.hov.neuralliquid.ai` (HOV-branded browser entrypoint to the current
  Mystira dev Identity App Service)
- App Service `asuid.*` TXT validation records for bound hosts

`login.hov` uses the dedicated
`mystira_identity_app_service_verification_id` input for its `asuid` TXT value;
it does not assume the NeuralLiquid App Services share Mystira Identity's ID.

## Backend

This stack uses the `azurerm` backend declared in `backend.tf`:

- resource group: `nl-org-tfstate-rg`
- storage account: `nlorgtfstate`
- container: `tfstate`
- key: `dns/terraform.tfstate`

Bootstrap that backend first with `infra/terraform/bootstrap/tfstate`. Use
`init -backend=false` only for validation before the backend exists.

## Import

Terraform import blocks are declared in `imports.tf`. With Terraform 1.5+,
`terraform apply` will import those existing records before managing them.

Use a remote-backend plan before apply:

```powershell
terraform -chdir=infra/terraform/bootstrap/tfstate init
terraform -chdir=infra/terraform/bootstrap/tfstate apply
terraform -chdir=infra/terraform/dns init
terraform -chdir=infra/terraform/dns plan
```
