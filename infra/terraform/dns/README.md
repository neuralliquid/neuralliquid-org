# DNS Terraform

This stack owns NeuralLiquid product DNS records in the Azure DNS zone:

- zone: `neuralliquid.ai`
- resource group: `nl-global-shared-rg`
- subscription: `5a95ddee-dd63-441a-8306-c8b0803dcdd4` (neuralliquid-sub)

**2026-08-19: zone migrated.** The zone was recreated fresh in `neuralliquid-sub`
during the org-wide DNS migration
(`docs/plans/azure-subscription-migration-plan.md`, Track B), populated by
capturing every live record via direct DNS queries (not from this file, which
had drifted — see the `login.hov` note below) and recreating them via `az`
CLI, then validated by querying the new zone's own nameservers directly. The
registrar's NS delegation cutover to the new zone is a separate step (requires
the domain owner's registrar login) — until that happens the *old* zone
(`mys-global-shared-rg`, subscription `bb4e3882-2079-4bab-8974-611bc0b8bb58`)
remains authoritative and live. That old zone is left in place, orphaned but
not deleted, as the rollback path — this repo/subscription never had access
to delete it anyway.

The zone itself is still read as a data source, not owned as a Terraform
resource — carried forward as-is from the pre-migration design. Worth
revisiting now that the zone lives somewhere this org actually controls.

## Current Scope

- `convolens.neuralliquid.ai`
- `omnipost.neuralliquid.ai`
- `cognitive-mesh.neuralliquid.ai`
- `control.cognitive-mesh.neuralliquid.ai`
- `api.cognitivemesh.neuralliquid.ai`
- `hov.neuralliquid.ai`
- `login.hov.neuralliquid.ai` (HOV-branded browser entrypoint to Mystira
  Identity — a Container App, not an App Service; this file's `record` value
  was stale/wrong from commit 5abc065 until 2026-08-19, see main.tf)
- App Service `asuid.*` TXT validation records for bound hosts
- Apex `@` A/MX/TXT records and `www`/`email` CNAMEs — newly IaC-owned as of
  the 2026-08-19 migration; previously unmanaged by any Terraform. The apex
  A/`www` CNAME point at `nl-prod-web-swa` (`infra/terraform/web`), a
  different Static Web App than `neuralliquid-web-prod` — see that repo's
  PRD open decision on apex-vs-subdomain before assuming these should change.

`login.hov` uses the dedicated
`mystira_identity_app_service_verification_id` input for its `asuid` TXT value;
it does not derive that value from the NeuralLiquid App Services input. The two
IDs currently have the same Azure-sourced value but remain independently
configurable so either can rotate without changing the other product hosts.

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
