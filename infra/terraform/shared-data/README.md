# Shared Data Terraform

This stack owns the shared NeuralLiquid PostgreSQL server in `neuralliquid-sub` —
the central data infrastructure for NeuralLiquid workloads.

- resource group: `nl-prod-shared-rg`
- server: `nl-prod-data-pg` (PostgreSQL 16, `B_Standard_B1ms`, 32 GB, South Africa North)
- vault: `nl-prod-data-kv` (RBAC-authorized)
- subscription: `5a95ddee-dd63-441a-8306-c8b0803dcdd4` (`neuralliquid-sub`)

## Ownership Line

The server, its resource group, its firewall, and the *existence* of each tenant
database are org-owned and managed here.

Everything **inside** a database — schema, tables, login roles, grants,
migrations — is owned by the product that uses it. This stack has no PostgreSQL
provider and holds no database credentials.

| Database | Owning product | Owning role | Notes |
| --- | --- | --- | --- |
| `convolens` | `convolens` | `convolens` | Primary NeuralLiquid tenant |

> **Removed (2026-09-12):** a `tarmac` tenant database was declared here,
> predating tarmac's move under the `celladore` GitHub org. It was never
> applied (`terraform plan` still showed it as 1 to add), so removing the
> declaration required no destroy. tarmac's home is `celladore-sub`'s
> `infrastructure/shared-data` stack.

> **HOV Exclusion Policy (ADR 0004 & Baton 37547ca3):**
> House of Veritas (`house-of-veritas`) is strictly excluded from `neuralliquid-sub`'s
> `nl-prod-data-pg`. Per ADR 0004, HOV is classified as a NexaMesh physical-estate
> product and will be migrated to an isolated datastore in `nex-prod-hov-rg` under
> `nexamesh-sub` (`8a5dc70a-bafa-4a04-a281-9b4862a70810`). The source `houseofveritas`
> database on `mystira-sub` remains untouched until that separately authorized migration.

Adding a database to `tenant_databases` is the org-level act of granting a
product a home on the shared server. The product then creates its own role and
schema. See [ADR 0002](../../../docs/adr/0002-shared-data-plane-ownership.md).


### Onboarding a Tenant

Terraform creates the database; the rest is not automated, and one step is easy
to miss:

1. Add the database to `tenant_databases` and apply.
2. Create the product's login role and transfer ownership of the database and
   its `public` schema to it. No product uses the server admin.
3. **`REVOKE CONNECT ON DATABASE <db> FROM PUBLIC`.** PostgreSQL grants `CONNECT`
   to `PUBLIC` on every new database, so until this is run, every other tenant on
   the server can open a connection to it. This is not something the stack can do
   for you — it is a grant inside a database, which the org does not own.
4. Store the product's connection string in *that product's* vault, not here.

Verify by connecting as the new role to another tenant's database and confirming
`permission denied for database`.

## Backend

- subscription: `5a95ddee-dd63-441a-8306-c8b0803dcdd4` (`neuralliquid-sub`)
- resource group: `nl-org-tfstate-rg`
- storage account: `nlorgtfstatesa`
- container: `tfstate`
- key: `shared-data/terraform.tfstate`

## Import

The PostgreSQL resources were adopted during the 2026-08-06 consolidation. That
history remains relevant, but this is now a greenfield `neuralliquid-sub` stack:
`imports.tf` deliberately contains no active import blocks. Do not re-enable
imports unless adopting an existing resource into this state is an explicit,
reviewed operation.

The vault and its role assignment were created by this stack, not imported.

```powershell
terraform -chdir=infra/terraform/shared-data init
terraform -chdir=infra/terraform/shared-data plan
```

A plan today should read **No changes**. Anything else is drift and worth
reading carefully.

## Secrets

Routine plans need no credential. `nl-prod-data-kv/postgres-admin-password`
holds the server admin password; nothing in this stack reads it, and no
application connects as that role.

The vault uses RBAC, not access policies, so subscription Owner alone does not
grant data-plane access — `key_vault_role_assignments` grants it explicitly.

A tenant's own connection string does **not** belong here. It belongs in that
product's vault: HOV's is at `nl-prod-hov-kv/estate-database-url`, and
convolens' tenant role password stays in `nl-prod-convolens-kv`.

## Changing the Server

There is a sharp edge worth knowing before you try.

The server is configured with Terraform 1.11's write-only
`administrator_password_wo` pair. When no `TF_VAR_administrator_password`
override is supplied, Terraform generates a complexity-compliant administrator
password and writes the same value to `nl-prod-data-kv/postgres-admin-password`.
Routine plans therefore need no operator-supplied credential.

The PostgreSQL provider does not expose the write-only password on the server
resource. The generated password and Key Vault secret are Terraform-sensitive
values, so state and Key Vault access remain privileged. Any administrator
password rotation must use the separately approved rotation runbook and update
the database and vault together; do not add and remove password arguments as an
ad hoc server-change workaround.

The two tags on the server were applied through the resource tags API for
exactly this reason — a metadata change was not worth sending a production
credential.

## Database Migration Procedure

For the step-by-step procedure to migrate the `convolens` database from the legacy server to `neuralliquid-sub` (including quiescence, `pg_dump`, SHA256 checksums, role setup, `pg_restore`, and integrity verification), see [Convolens Database Migration Runbook](../../../docs/runbooks/convolens-database-migration.md).

## Deliberate Non-Goals

- **The Azure-generated firewall rule name is kept as-is.** Renaming it to
  something readable would destroy and recreate the rule, briefly cutting the
  Convolens tenant application off the server. Not worth the tidiness.
- **`prevent_destroy` is set on tenant databases.** Removing a product from the
  map will fail the plan rather than drop its database. Decommissioning a tenant
  is a deliberate, out-of-band act.
- **No private networking.** Access is by the Azure-services firewall allowance.
  Moving to a delegated subnet and private DNS zone is a real improvement and a
  separate decision, because it touches the tenant's connection path.

