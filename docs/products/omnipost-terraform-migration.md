# Omnipost Terraform Migration Notes

## Current Posture

Omnipost is still being brought live by an active agent. Do not delete Bicep,
change DNS, or apply replacement Terraform until the agent-created target is
known and stable.

Known current DNS issue:

- `omnipost.neuralliquid.ai` currently points at `neuralliquid.ai` and returns an
  Azure default 404.
- The desired final state is a product-owned Azure app with org-owned DNS.

## Bicep Disposition

Remove these files only after equivalent Terraform exists, imports are complete,
and the live path is verified:

| File | Final owner | Terraform disposition |
| --- | --- | --- |
| `infra/dns.bicep` | `neuralliquid-org` | Replace with org DNS Terraform. |
| `infra/dns-records.bicep` | `neuralliquid-org` | Replace with org CNAME and `asuid.*` TXT records. |
| `infra/custom-domain.bicep` | `omnipost` | Replace with product Terraform for hostname binding, managed certificate, and certificate binding. |
| `infra/main.bicep` | `omnipost` | Replace with the Omnipost root Terraform stack. |
| `infra/monitoring.bicep` | `omnipost` | Replace with product observability Terraform following org standards. |
| `infra/keyvault.bicep` | `omnipost` | Replace with product Key Vault and secret-boundary Terraform. |
| `infra/postgresql.bicep` | `omnipost` | Replace with product data Terraform unless the database is intentionally shared. |
| `infra/sluice.bicep` | TBD | Keep in Omnipost only if private to Omnipost; otherwise move to Sluice/shared-services ownership, not org DNS/control plane. |
| `infra/naming.bicep` | none | Replace with Terraform locals and org naming conventions. |
| `infra/naming.sh` | none | Remove after Terraform naming conventions are in place. |

## Re-entry Checklist

Before migration starts:

- Identify the live agent command path and branch.
- Identify Azure subscription, resource group, app name, app service plan, and
  app default hostname.
- Identify whether the agent produced Terraform state, Bicep deployments, or
  manual Azure resources.
- Capture current app health and expected hostname.
- Decide import versus replacement.
- Confirm no second IaC system will continue modifying the same resources.

After the app target is stable:

- Add or update `omnipost.neuralliquid.ai` CNAME in `neuralliquid-org` DNS
  Terraform.
- Add the required `asuid.omnipost` TXT validation record in org DNS Terraform.
- Add hostname binding and managed certificate resources in Omnipost Terraform.
- Run plan/validate in both states and apply in the correct order: DNS first,
  product binding second.
- Delete Bicep only after the Terraform-owned deployment is healthy.
