# Shared Data Terraform

This stack owns the shared NeuralLiquid PostgreSQL server — the one piece of
data infrastructure that no single product can own, because two products sit on
it.

- resource group: `nl-prod-shared-rg`
- server: `nl-prod-shared-pg` (PostgreSQL 16, `B_Standard_B1ms`, 32 GB, South Africa North)
- subscription: `bb4e3882-2079-4bab-8974-611bc0b8bb58`

## Ownership Line

The server, its resource group, its firewall, and the *existence* of each tenant
database are org-owned and managed here.

Everything **inside** a database — schema, tables, login roles, grants,
migrations — is owned by the product that uses it. This stack has no PostgreSQL
provider and holds no database credentials.

| Database | Owning product | Owning role |
| --- | --- | --- |
| `houseofveritas` | `house-of-veritas` | `houseofveritas` |
| `convolens` | `convolens` | `convolens` |

Adding a database to `tenant_databases` is the org-level act of granting a
product a home on the shared server. The product then creates its own role and
schema. See [ADR 0002](../../../docs/adr/0002-shared-data-plane-ownership.md).

## Backend

- resource group: `nl-org-tfstate-rg`
- storage account: `nlorgtfstate`
- container: `tfstate`
- key: `shared-data/terraform.tfstate`

## Import

Every resource here already exists — it was created with `az` during the
2026-08-06 consolidation and has been drift since. `imports.tf` adopts it.
Nothing in this stack creates infrastructure.

```powershell
terraform -chdir=infra/terraform/shared-data init
terraform -chdir=infra/terraform/shared-data plan
```

A correct first plan reads **7 to import, 0 to add, 1 to change, 0 to destroy**.
The single change is adding `environment` and `project` tags to the server,
which was created untagged.

## Secrets

Nothing in this stack requires a password to plan or apply.
`administrator_password` defaults to `null` and is in `ignore_changes`, so
Terraform never reads, writes, or diffs it. The live value is held in Key Vault
and rotated out of band; supply the variable only if the server must be
recreated.

## Deliberate Non-Goals

- **The Azure-generated firewall rule name is kept as-is.** Renaming it to
  something readable would destroy and recreate the rule, briefly cutting both
  applications off the server. Not worth the tidiness.
- **`prevent_destroy` is set on tenant databases.** Removing a product from the
  map will fail the plan rather than drop its database. Decommissioning a tenant
  is a deliberate, out-of-band act.
- **No private networking.** Access is by the Azure-services firewall allowance.
  Moving to a delegated subnet and private DNS zone is a real improvement and a
  separate decision, because it touches both tenants' connection paths at once.
