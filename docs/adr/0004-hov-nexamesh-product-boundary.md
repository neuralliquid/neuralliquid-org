# ADR 0004: House of Veritas as a NexaMesh Product

## Status

Accepted — 2026-08-21

## Context

ADR 0003 grouped House of Veritas (HOV) with NeuralLiquid's applied AI
products, but did not record product-level reasoning for that placement. The
classification was later copied into the Azure subscription migration plan,
where it became an assumed infrastructure destination.

HOV's authoritative product thesis is now:

> House of Veritas is an intelligent physical estate governed by AI.

HOV is the estate's command and governance layer for people, spaces, assets,
vehicles, work, money, documents, incidents, and accountable decisions.
NexaMesh is the physical-world platform for trusted device identity, sensing,
edge execution, mesh transport, and evidence. NeuralLiquid services may provide
reasoning or analysis through explicit service contracts, but they do not own
the estate product or its records.

The current implementation is not yet a complete cyber-physical system. Its
live value is primarily the estate control plane and human workflow layer.
Sensor ingestion, device twins, local edge agents, and automated physical
responses remain roadmap capabilities and must not be represented as deployed.

## Options considered

### 1. Keep HOV in NeuralLiquid

This matches the current repository organization and the historical
`hov.neuralliquid.ai` hostname. It fits the application's current SaaS-shaped
implementation, but treats its physical-estate purpose as incidental and makes
the future NexaMesh relationship look like an optional integration.

### 2. Make HOV a NexaMesh product

This makes HOV the first vertical product built on the NexaMesh physical-world
platform. It gives NexaMesh a concrete civilian application while keeping HOV
responsible for estate meaning, governance, and sensitive domain records.

### 3. Make HOV fully standalone

This maximizes brand and infrastructure independence, but creates a third
platform boundary before HOV's scale or regulatory posture justifies it. A
dedicated HOV subscription remains a future isolation option.

## Decision

Adopt option 2. HOV is a distinct NexaMesh product and reference vertical, not
a generic NexaMesh feature. Its intended Azure destination is `nexamesh-sub`
inside the Celladore Systems tenant, with HOV-specific resource groups,
Terraform state, identities, Key Vault, storage, database, monitoring, and cost
attribution.

This decision supersedes ADR 0003 only where that ADR placed HOV in the
NeuralLiquid product family. It does not change ADR 0003's Celladore developer
tooling decision or reclassify unrelated products.

## Product and platform boundary

| Owner | Responsibilities |
| --- | --- |
| HOV | Estate state, people and roles, work orders, assets, incidents, financial and employment records, household policy, decisions, and retained domain evidence |
| NexaMesh platform | Device identity, trusted observations, edge execution, mesh transport, device health, generic telemetry routing, and provenance primitives |
| NeuralLiquid services | Optional reasoning, document intelligence, model routing, and analytics reached through versioned service contracts |

A physical observation crosses the boundary as a minimal authenticated event.
For example, NexaMesh may attest that a water sensor reported an abnormal
reading; HOV decides whether that creates an estate incident, who is assigned,
what was spent, and how the outcome is preserved.

NexaMesh shared services must not receive unrestricted access to household,
employee, biometric, legal, or financial records. HOV remains the system of
record for those domains even when the originating observation came from a
NexaMesh device or edge agent.

## Infrastructure consequences

- The existing HOV production stack remains unchanged until a separately
  reviewed and authorized migration is executed.
- The old plan to move HOV into `neuralliquid-sub` is withdrawn.
- The target is an isolated `nex-prod-hov-rg` product boundary in
  `nexamesh-sub`, not the NexaMesh shared-services resource group.
- Cross-subscription Terraform state is not repointed. The migration must use a
  new backend and a reviewed rebuild/import/cutover strategy.
- HOV must leave the NeuralLiquid shared PostgreSQL server for an isolated,
  independently restorable datastore in `nex-prod-hov-rg`. Cutover requires a
  successful independent backup/restore rehearsal and explicit acceptance of
  the restored data boundary. **Deprioritized 2026-08-26:** HOV is not yet in
  active/live use, so that rehearsal is not being scheduled at this time.
  Revisit when that changes — see `nexamesh-org` ADR 0002's open items.
- **`sign.nexamesh.ai` and `ops.nexamesh.ai` ownership — resolved 2026-08-26.**
  `nexamesh-org` ADR 0002 records the decision on the receiving side: **shared
  NexaMesh service**, owned by the `nexamesh-org` control plane, not moved
  into the HOV product boundary. Both are confirmed (not inferred) as
  `nex-prod-docuseal-ca` and `nex-prod-baserow-ca` in `nex-prod-services-rg`
  (`nexamesh-sub`), each with its own managed certificate on the shared
  `nex-prod-services-cae` Container Apps environment. Neither is under any
  Terraform state yet — adopting them is a follow-up in `nexamesh-org`, not
  this repo. The tenant isolation, availability, data retention, and API
  contracts a shared service implies (per the migration addendum's Phase 4
  gate) remain open and are not resolved by this decision alone.
- `hov.neuralliquid.ai` remains a compatibility hostname until a separate DNS,
  identity-callback, certificate, and user-communication cutover is approved.

## Consequences

### Positive

- NexaMesh gains a concrete product family: platform capabilities plus an
  understandable physical-world vertical.
- HOV's long-term physical-estate architecture becomes explicit without
  claiming unbuilt edge capabilities are live.
- Sensitive HOV data remains product-isolated while shared NexaMesh primitives
  stay reusable.
- Azure ownership, cost attribution, DNS, and product narrative can converge on
  the same target.

### Negative and trade-offs

- Four repositories and existing Baton migration tasks need coordinated
  amendments.
- HOV currently shares PostgreSQL infrastructure with Convolens, so the new
  boundary requires a data migration rather than a simple App Service move.
- Existing NeuralLiquid hostnames, OIDC client configuration, resource names,
  and GitHub ownership create a staged transition rather than an instant
  rebrand.
- NexaMesh must avoid diluting its platform story into an unbounded collection
  of vertical features.

## Revisit triggers

Reconsider a dedicated `hov-sub` when HOV becomes revenue-generating, needs an
independent restore or compliance boundary, holds materially more regulated
personal data, or its operational blast radius is no longer acceptable inside
the broader NexaMesh subscription.

## Related material

- [ADR 0003: Celladore Org Split and Developer Stack Separation](./0003-celladore-org-split-exploration.md)
- [HOV to NexaMesh migration addendum](../plans/hov-nexamesh-migration-addendum.md)
- [NeuralLiquid Azure subscription migration plan](../plans/azure-subscription-migration-plan.md)
