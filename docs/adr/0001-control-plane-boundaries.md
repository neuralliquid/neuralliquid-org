# ADR 0001: Control Plane and Product Repo Boundaries

## Status

Accepted

## Context

NeuralLiquid has four active product repositories:

- `convolens`
- `omnipost`
- `cognitive-mesh`
- `house-of-veritas`

The organization needs a durable control plane similar to `phoenixvc-org`, but it
should not become a monorepo for every product runtime. DNS, governance, launch
standards, and factory patterns need one source of truth. Product workloads still
need local ownership so runtime changes stay close to app code, release gates,
and product-specific operators.

Omnipost is currently excluded from destructive migration because a live agent is
actively bringing it online. Until that target is stable, the org repo should
record intent and readiness checks only.

## Decision

`neuralliquid-org` is the organizational control plane and product factory.
Product repositories are the workload planes.

The org repo owns:

- `neuralliquid.ai` DNS zone records and validation TXT records.
- Product inventory, canonical hostnames, dependency maps, and launch runbooks.
- Terraform backend standards and state ownership rules.
- GitHub organization, repository, environment, and OIDC policy standards.
- Azure naming, tagging, RBAC, budget, and cost-control standards.
- Shared action groups, alert severity policy, dashboard/workbook patterns, and
  observability defaults.
- Reusable factory templates for new products.

Product repos own:

- Application source and deployment pipelines.
- Product runtime infrastructure: App Service, Container Apps, App Service Plans,
  slots, databases, storage, queues, Key Vaults, and managed identities.
- Product monitoring resources: Application Insights, diagnostic settings,
  availability checks, and product-specific alerts.
- App Service or Container App custom hostname bindings and managed certificates.
- Product-specific Terraform state.

## Terraform State Rule

A live Azure resource must be managed by exactly one Terraform state.

DNS records under `neuralliquid.ai` should eventually be managed by
`neuralliquid-org`, but records already managed by product Terraform must be
migrated through a deliberate state handoff. Do not duplicate them in another
state.

## Consequences

- `neuralliquid-org` can standardize launches without owning every runtime.
- Product teams and agents can ship app changes without needing org-control-plane
  applies.
- DNS and validation records stop drifting across Mystira, product repos, and
  manual portal edits.
- Cross-product standards become reusable while product stacks remain bounded.
