# ADR 0002: Shared Data Plane Ownership

## Status

Accepted

## Context

[ADR 0001](./0001-control-plane-boundaries.md) puts databases squarely in the
product plane: "Product runtime infrastructure: App Service, Container Apps,
App Service Plans, slots, **databases**, storage, queues, Key Vaults, and
managed identities."

That line assumes each database belongs to exactly one product. On 2026-08-06 a
case appeared that does not fit. House of Veritas needed a PostgreSQL server and
Convolens already had one. A dedicated second server was rejected on cost — at
alpha, two `B1ms` instances is a real fraction of the monthly bill for no
operational gain. HOV was therefore placed on `nl-prod-convolens-pg`, which made
it a guest on another product's production instance, sharing an administrative
credential and a restore boundary.

Both applications were then moved onto a new neutral server,
`nl-prod-shared-pg`, in a new resource group, `nl-prod-shared-rg`. The server
count — and therefore the cost — is unchanged, but neither product is a guest of
the other. See House of Veritas
[ADR-013](https://github.com/neuralliquid/house-of-veritas/blob/main/docs/02-architecture/13-database-hosting-adr.md)
for the product-side reasoning.

That server was created with `az` during the migration and belonged to no
Terraform state. Under the Terraform State Rule in ADR 0001 — "a live Azure
resource must be managed by exactly one Terraform state" — it was drift from the
moment it existed, and it had no natural home: putting it in either product's
state would recreate the guest relationship in code.

## Decision

**Shared data infrastructure is org-owned. Product-specific data infrastructure
stays product-owned.** ADR 0001's product-plane list is amended accordingly: it
covers databases used by exactly one product.

The boundary runs at the database boundary, not the server boundary:

- **Org owns** the resource group, the server, its SKU, storage, backup
  configuration, firewall, server parameters, and the *existence* of each tenant
  database. These are managed in `infra/terraform/shared-data`.
- **Products own** everything inside their database: schema, tables, login
  roles, grants, and migrations. Products also own their own connection string
  and the app settings that consume it.

The org stack holds no database credentials and configures no PostgreSQL
provider. Granting a product a home on the shared server is an org act; making
that home useful is a product act.

A product-specific database — one product, one server, no tenancy question —
remains product-owned under ADR 0001 unchanged. House of Veritas' Terraform
still defines its own `enable_database` module for exactly that case; it is
simply switched off in favour of shared tenancy.

## Consequences

- `nl-prod-shared-pg` is codified and no longer drift. The import plan showed
  the config faithful to the live server, with one correction: the server had
  been created with no tags, in violation of the org tagging convention.
- Adding a third tenant is a reviewed change to one map in one org stack, rather
  than an `az` command someone runs during an unrelated migration.
- **The blast radius is now explicit rather than accidental.** One server means
  one restart, one storage limit, one maintenance window, one CPU-credit budget,
  shared across products. Owning it at org level does not reduce that; it makes
  the shared risk visible and reviewable in one place.
- **Restore stays server-scoped.** Point-in-time restore affects every tenant.
  Per-database recovery requires a dump, not PITR. A product that needs an
  independent restore window has outgrown shared tenancy and should move to its
  own server — the move is `pg_dump`, restore, change the connection string.
- **`PUBLIC` retains `CONNECT` on each database by default.** PostgreSQL grants
  it, so either tenant role can open a connection to the other's database,
  though it holds no rights on that database's objects. Closing this is
  `REVOKE CONNECT ON DATABASE <db> FROM PUBLIC` per database. It touches each
  product's own access path, so it belongs to the products, coordinated — not to
  a unilateral org apply.
- Credentials now follow the same ownership line. `nl-prod-shared-kv` was created
  in `nl-prod-shared-rg` for secrets belonging to the server itself, and holds
  `postgres-admin-password`. HOV's connection string moved to
  `nl-prod-hov-kv/estate-database-url`. `nl-prod-convolens-kv` keeps only
  convolens' own secrets, including its tenant role password. Before this, one
  product's vault was acting as the org credential store.
- The new vault uses RBAC rather than access policies, so data-plane access is
  granted explicitly per principal in `key_vault_role_assignments` rather than
  inherited from subscription Owner.
- **azurerm cannot update the server without its admin password**, whatever
  `ignore_changes` says, and declaring the write-only credential pair against
  null variables produces a permanent un-appliable diff. The config therefore
  declares no password attribute, and a genuine server change is a deliberate
  two-step documented in the stack README. This is a provider constraint, not a
  preference; it is recorded so the next person does not rediscover it.

## Revisit Triggers

Move a product off the shared server when any of these becomes true:

- it needs an independent maintenance or restore window;
- contention appears on the `B1ms` — connection exhaustion, storage pressure, or
  CPU credit depletion;
- it holds regulated personal data at a volume that makes shared tenancy
  uncomfortable;
- it becomes revenue-generating, or the cost constraint otherwise relaxes.
