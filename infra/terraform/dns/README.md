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
- App Service `asuid.*` TXT validation records for bound hosts

## Import

Terraform import blocks are declared in `imports.tf`. With Terraform 1.5+,
`terraform apply` will import those existing records before managing them.

Use a plan first:

```powershell
terraform -chdir=infra/terraform/dns init
terraform -chdir=infra/terraform/dns plan
```
