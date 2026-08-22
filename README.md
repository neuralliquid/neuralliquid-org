# NeuralLiquid Org

Organizational control plane and product factory for NeuralLiquid.

This repo owns shared governance and cross-product platform contracts for the
NeuralLiquid product set:

- Convolens
- Omnipost
- Cognitive Mesh
- VeritasVault

House of Veritas is transitioning out of this product set into the NexaMesh
product family under [ADR 0004](docs/adr/0004-hov-nexamesh-product-boundary.md).
This repository continues to document its current `neuralliquid.ai` DNS and
shared-data dependencies until the separately approved migration is complete.

Under exploration / candidate for `celladore` developer org:
- Sluice (Event streaming & queue routing)
- Docket (Task ledger & state persistence)
- Baton (Agent handoff protocol & lease orchestration)
- Deck (Developer console & operator UI)

Product repos continue to own application code and product-specific runtime
infrastructure. This repo owns the shared control plane: DNS, GitHub/Azure
organization policy, repo onboarding standards, product inventory, and reusable
factory patterns. Upstream portfolio intelligence, cross-repo roadmaps, and the
canonical project registry are maintained in [`org-meta`](../org-meta/README.md).

## Current Priority

Stabilize `neuralliquid.ai` DNS ownership and remove product subdomain drift.

**DNS zone migration to Cloudflare complete (2026-08-19).** The `neuralliquid.ai`
zone is now delegated to Cloudflare (`jack.ns.cloudflare.com` /
`laylah.ns.cloudflare.com`), leaving the prior Azure DNS zones orphaned as
rollback references. See [`docs/inventory/dns.md`](docs/inventory/dns.md) for
the full execution log and [`infra/terraform/dns-cloudflare/README.md`](infra/terraform/dns-cloudflare/README.md).

Known live state as of 2026-08-21:

| Host | Current target | Status |
| --- | --- | --- |
| `convolens.neuralliquid.ai` | `nl-prod-convolens-web-nl.azurewebsites.net` | Healthy — corrected 2026-08-21 |
| `omnipost.neuralliquid.ai` | `nl-dev-omnipost-web.azurewebsites.net` | Healthy — corrected 2026-08-19 |
| `cognitive-mesh.neuralliquid.ai` | `cognitive-mesh-frontend-prod.azurewebsites.net` | Healthy |
| `hov.neuralliquid.ai` | `nl-prod-hov-app.azurewebsites.net` | Healthy |
| `www.neuralliquid.ai` | `black-plant-0aaf54b0f.7.azurestaticapps.net` | Healthy — pointed at `neuralliquid-web-prod` SWA on `neuralliquid-sub` |

Both `neuralliquid.ai` (apex) and `www.neuralliquid.ai` now resolve with valid TLS.

## Repo Boundary

This repo should own:

- `neuralliquid.ai` DNS zone records and validation TXT records.
- GitHub organization/repository policy and environment standards.
- Azure subscription/resource-group conventions, RBAC, OIDC, budgets, and shared monitoring standards.
- Product onboarding templates and launch runbooks.
- Cross-product inventory of hostnames, owners, environments, and dependencies.

Product repos should own:

- Application source code.
- Product-specific Terraform/Bicep for app resources.
- Runtime settings, single-product databases, queues, storage, and application
  deployment pipelines.
- Schema, roles and grants inside a database on the shared server.
- App Service/Container App hostname bindings and certificates where those resources live.

Shared data infrastructure — a server used by more than one product — is an
exception owned here, not by either tenant. See
[ADR 0002](docs/adr/0002-shared-data-plane-ownership.md).

## Layout

```text
docs/
  architecture/
  inventory/
  runbooks/
infra/
  terraform/
    bootstrap/
      tfstate/
    dns/
    dns-cloudflare/
    github/
    azure/
    shared-data/
products/
  <product>.yaml
```

## Planning Artifacts

- [ADR 0001: Control Plane and Product Repo Boundaries](docs/adr/0001-control-plane-boundaries.md)
- [ADR 0002: Shared Data Plane Ownership](docs/adr/0002-shared-data-plane-ownership.md)
- [ADR 0003: Celladore Org Split and Developer Stack](docs/adr/0003-celladore-org-split-exploration.md)
- [ADR 0004: House of Veritas as a NexaMesh Product](docs/adr/0004-hov-nexamesh-product-boundary.md)
- [Terraform Control Plane Phases](docs/plans/terraform-control-plane-phases.md)
- [Funding & Ecosystem Strategy](docs/plans/funding-strategy-and-ecosystem-programs.md)
- [Azure Subscription Migration Plan & Taskgraph](docs/plans/azure-subscription-migration-plan.md)
- [HOV to NexaMesh Migration Addendum](docs/plans/hov-nexamesh-migration-addendum.md)
- [Terraform CI and Apply](docs/runbooks/terraform-ci.md)
- [Omnipost Terraform Migration Notes](docs/products/omnipost-terraform-migration.md)

## First Milestone

1. Bootstrap the `neuralliquid-org` remote Terraform state backend.
2. Import the `neuralliquid.ai` DNS record model into Terraform state.
3. Move Omnipost away from `CNAME -> neuralliquid.ai` once the target app exists.
4. Reconcile Convolens and HOV manual DNS/custom-domain drift into durable product IaC.
5. Decide whether Cognitive Mesh DNS moves here immediately or remains a documented temporary exception.

**Status:**

- [x] **Milestone 1** — `infra/terraform/bootstrap/tfstate` exists and is the
  shared backend for every stack in this repo.
- [x] **Milestone 3** — Omnipost CNAME corrected from the bare apex to
  `nl-dev-omnipost-web.azurewebsites.net` (verified 2026-08-19).
- [x] **DNS zone migration** — zone delegated to Cloudflare 2026-08-19; Azure
  DNS zones orphaned as rollback references (`docs/inventory/dns.md`).
- [~] **Milestone 2** — `infra/terraform/dns-cloudflare` (the intended live
  IaC owner) is written and `terraform validate`-clean in CI, but records are
  still imported from the live zone only via out-of-band
  `scripts/generate-imports.sh`; `imports.tf` not yet generated. The Azure
  `infra/terraform/dns` stack remains as the rollback-reference counterpart.
- [~] **Milestone 4** — Convolens CNAME corrected to `...-nl.azurewebsites.net`
  across `docs/inventory/dns.md`, `infra/terraform/dns*`, and
  `products/convolens.yaml` (verified 2026-08-21), but the product repo still
  needs to reconcile hostname binding/certificate drift into its own IaC.
- [ ] **Milestone 5** — Cognitive Mesh DNS ownership decision pending; its
  records still live in its own Terraform stack (documented temporary
  exception).
