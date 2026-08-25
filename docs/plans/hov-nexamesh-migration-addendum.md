# HOV to NexaMesh Subscription Migration Addendum

**Status:** Architecture accepted; execution not yet authorized

**Decision:** [ADR 0004](../adr/0004-hov-nexamesh-product-boundary.md)

**HOV tracking:** Baton `37547ca3-c6fa-47ac-a30d-b3e1348bcf07`

## Purpose

This addendum replaces the HOV slice of the NeuralLiquid subscription migration
plan. It records the intended destination and the safety gates that must be met
before any Terraform, data, DNS, identity, or decommissioning action.

It is not approval to run a migration.

## Source and target

| Boundary | Current | Intended target |
| --- | --- | --- |
| Entra tenant | `Default Directory` (`9530cd32-9e33-47f0-9247-ed964730b580`) | Celladore Systems (`5384ef74-e517-4b22-9472-df990f61e8b5`) |
| Subscription | `Azure subscription 1` (`bb4e3882-2079-4bab-8974-611bc0b8bb58`) | `nexamesh-sub` (`8a5dc70a-bafa-4a04-a281-9b4862a70810`) |
| HOV runtime resource group | `nl-prod-hov-rg` | `nex-prod-hov-rg` |
| Terraform backend | `hov-shared-tfstate-rg` / `hovsharedtfstatesa` in the source subscription | New HOV-isolated backend in `nexamesh-sub`; exact names require a reviewed bootstrap plan |
| Primary hostname | `hov.neuralliquid.ai` | Compatibility host during migration; `hov.nexamesh.ai` is the proposed product-family host and needs separate approval |

Live preflight on 2026-08-21 found no HOV App Service, resource group, or
Terraform backend in any Celladore Systems subscription. The current HOV
Terraform also contains source-subscription import IDs. Pointing it at
`nexamesh-sub` would therefore propose a second stack or fail imports; it is not
a migration mechanism.

## Target boundaries

```text
nexamesh-sub
├── nex-prod-shared-rg
│   └── reusable NexaMesh platform services
├── nex-prod-services-rg
│   └── currently deployed shared services requiring ownership review
└── nex-prod-hov-rg
    ├── HOV web application and plan
    ├── HOV Key Vault and managed identities
    ├── HOV storage and retained estate evidence
    ├── HOV database and restore boundary
    └── HOV monitoring, alerts, and budgets
```

Shared NexaMesh services communicate with HOV through versioned, authenticated
contracts. Subscription co-location does not grant data-plane access.

## Migration phases and gates

### Phase 0: Freeze the source inventory

- Inventory every HOV-owned Azure resource, hostname binding, certificate,
  identity, role assignment, secret reference, database, storage container,
  monitoring dependency, and external service.
- Separate HOV-owned resources from shared dependencies such as identity,
  Cloudflare DNS, DocuSeal, Baserow, and the NeuralLiquid PostgreSQL server.
- Capture cost, region, SKU, backup, retention, and recovery requirements.
- Reconcile the inventory with Terraform state and record unmanaged drift.

**Gate:** reviewed source inventory with an explicit owner and disposition for
every live dependency.

### Phase 1: Bootstrap the target control plane

- Create HOV-specific GitHub OIDC federation for the target subscription.
- Bootstrap a new remote state backend without copying or repointing the old
  state file.
- Update provider, backend, imports, naming, and environment configuration for
  `nexamesh-sub`.
- Produce a full target plan and a separate source-retirement plan.

**Gate:** exact-revision plan with no unexplained resources, replacements,
secret exposure, or source deletion.

### Phase 2: Establish HOV-owned data services

- Provision an isolated, independently restorable HOV datastore in
  `nex-prod-hov-rg`. A non-PostgreSQL alternative requires explicit approval,
  but it may not weaken product isolation or the independent restore contract.
- Export and restore only the HOV database from `nl-prod-shared-pg`; preserve
  Convolens and the NeuralLiquid shared server.
- Migrate required HOV storage and Key Vault material using approved secure
  channels, then rotate credentials and keys.
- Verify scoped roles cannot access other product databases or vaults.

**Gate:** row/count/checksum evidence, application-level read/write probes,
backup/restore proof, least-privilege checks, and an exercised rollback path.

### Phase 3: Deploy the HOV runtime without public cutover

- Deploy the HOV web application, monitoring, and any explicitly enabled
  workers to `nex-prod-hov-rg`.
- Keep the current Mystira-compatible OIDC issuer and callbacks unless a
  separately coordinated identity change is approved.
- Validate health, data semantics, outbound integrations, and cost controls on
  the target Azure hostname.

**Gate:** exact-build verification and legitimate role-based acceptance on the
target without changing public DNS.

### Phase 4: Reconcile NexaMesh services

- ~~Decide whether `sign.nexamesh.ai` and `ops.nexamesh.ai` are shared
  NexaMesh services or HOV-owned services.~~ **Decided 2026-08-26: shared
  NexaMesh service**, owned by the `nexamesh-org` control plane — see
  `nexamesh-org` ADR 0002 and this org's ADR 0004. Not yet backed by
  Terraform on the `nexamesh-org` side.
- Still open: define tenant isolation, availability, data retention, and API
  contracts for that shared service. This was not resolved by the ownership
  decision above and remains blocking for this phase's gate.
- Do not claim sensor, device-twin, mesh, or edge-agent capability until a real
  implementation and acceptance evidence exist.

**Gate:** documented service ownership (done) and tested failure/isolation
behavior (still open — tenant isolation/availability/data retention/API
contracts above).

### Phase 5: DNS and identity-compatible cutover

- Establish an approved write-stop or equivalent consistency boundary, perform
  a final synchronization from the source, and re-run row/count/checksum checks
  before routing production writes to the target. Do not allow target
  acceptance writes to diverge from the source before this transition.
- Keep `hov.neuralliquid.ai` as a compatibility hostname initially.
- If `hov.nexamesh.ai` is approved, provision validation records, hostname
  binding, managed certificate, Auth.js trusted-host settings, and Mystira OIDC
  callback/post-logout allowlists before changing user-facing links.
- Lower TTLs only within the approved window and retain a tested rollback
  target.

**Gate:** The final data synchronization and write transition are recorded;
DNS, TLS, health, authentication redirect, callback, sign-out, and legitimate
HOV user acceptance all pass on the chosen canonical hostname.

### Phase 6: Observe, then retire the source

- Observe target health, errors, database behavior, background jobs, and user
  flows for an agreed period.
- Confirm no production traffic, secret references, database connections, or
  scheduled jobs remain on the source.
- Remove HOV from NeuralLiquid shared infrastructure only after both HOV and
  NeuralLiquid owners accept the evidence.

**Gate:** separately authorized, resource-by-resource retirement plan. No
resource-group deletion is implied by this addendum.

## Explicit non-goals for the documentation phase

- No `terraform init`, plan, apply, import, state move, or destroy.
- No Azure resource creation, movement, or deletion.
- No database export, restore, or credential rotation.
- No DNS, certificate, hostname, repository-transfer, or OIDC mutation.
- No claim that HOV's future sensor and edge architecture is live today.

## Rollback principles

- Blue/green target deployment precedes public cutover.
- Source resources remain intact until the observation gate closes.
- Database writes must have a documented cutover point; dual-write is not
  assumed safe.
- DNS rollback must restore both hostname routing and identity callback
  consistency.
- A failed target plan or acceptance gate stops the migration without altering
  production.
