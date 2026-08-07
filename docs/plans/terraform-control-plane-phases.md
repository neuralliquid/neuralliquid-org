# Terraform Control Plane Phases

## Goal

Move NeuralLiquid infrastructure to Terraform with clear ownership boundaries,
minimal cost growth, and no disruption to Omnipost while its live agent is still
bringing the product online.

## Phase 0: Control Plane Baseline

Owner: `neuralliquid-org`

- Keep the org repo as the source for inventory, DNS inventory, runbooks, and
  Terraform ownership rules.
- Establish the remote Terraform backend with
  `infra/terraform/bootstrap/tfstate` before any org-level apply.
- Record ADRs for repo boundaries, Terraform state ownership, DNS ownership,
  monitoring/logging policy, and cost-control defaults.
- Make no product runtime changes in this phase.

Exit criteria:

- Boundary ADR exists.
- Phase plan exists.
- DNS Terraform validates with `init -backend=false`, and the backend bootstrap
  stack has a reviewed plan before any DNS apply.

## Phase 1: DNS Ownership Hardening

Owner: `neuralliquid-org`

- Import confirmed-good DNS records for `convolens.neuralliquid.ai`,
  `omnipost.neuralliquid.ai`, `hov.neuralliquid.ai`, and the Cognitive Mesh
  NeuralLiquid hostnames.
- Maintain a DNS cutover runbook for CNAME, `asuid.*` TXT validation, managed
  certificates, TTLs, and rollback.

Exit criteria:

- Org DNS state has no duplicate ownership with product states.
- `terraform plan` shows only intended imports/changes.

## Phase 2: Convolens Product Boundary

Owner: `convolens`

- Keep app/runtime Terraform in the Convolens repo.
- Ensure Convolens owns its App Service, App Service Plan, hostname binding,
  managed certificate binding, diagnostics, and product monitoring.
- Ensure `neuralliquid-org` owns only DNS CNAME/TXT records.
- Add product docs pointing to org DNS ownership.

Exit criteria:

- Convolens app resources and DNS resources have separate state owners.
- Convolens production TLS remains healthy.

## Phase 3: House of Veritas Product Boundary

Owner: `house-of-veritas`

- Keep HOV app/runtime infrastructure in the HOV repo.
- Move only `hov.neuralliquid.ai` DNS records to `neuralliquid-org` once current
  state ownership is verified.
- Check for deployment templates or docs that still assume product-owned DNS.

Exit criteria:

- HOV runtime remains product-owned.
- HOV DNS ownership is documented and drift-free.

## Phase 4: Cognitive Mesh Product Boundary Review

Owner: `cognitive-mesh` and `neuralliquid-org`

- Keep Cognitive Mesh app/runtime infrastructure in the Cognitive Mesh repo.
- Confirm product Terraform no longer owns the org-imported DNS records:
  - `cognitive-mesh.neuralliquid.ai`
  - `control.cognitive-mesh.neuralliquid.ai`
  - `api.cognitivemesh.neuralliquid.ai`
- If product state still owns one of these records, remove it from product state
  with a deliberate state handoff. Do not manage the same record from two states.

Exit criteria:

- Product runtime remains product-owned.
- DNS state ownership is documented and duplicate ownership is removed.

## Phase 5: Org Factory Layer

Owner: `neuralliquid-org`

- Add product launch templates.
- Add GitHub Actions and OIDC baseline documentation.
- Add Azure naming, tagging, environment, and cost-control defaults.
- Add alert templates and dashboard/workbook patterns.
- Add product inventory schema and onboarding checklist.

Exit criteria:

- A new product can be launched from documented factory steps without copying
  stale product-specific infrastructure.

## Phase 6: Observability and Cost Controls

Owner: shared standards in `neuralliquid-org`; product implementation in product
repos

- Org owns shared action groups, budget alerts, alert severities, dashboard
  patterns, retention defaults, and cost review cadence.
- Product repos own Application Insights, diagnostic settings, product alerts,
  availability checks, and runtime log queries.
- Prefer lean dev/eval defaults and avoid premium networking or isolated shared
  services until there is an operational reason.

Exit criteria:

- Each product has a minimum viable observability profile.
- Org-level cost alerts exist for shared scope.

## Phase 7: Omnipost Runtime Re-entry

Owner: `omnipost` and `neuralliquid-org`

Omnipost DNS is live and should be imported into org DNS. Runtime/Bicep
migration remains product-owned and should wait until the live path is stable.

- Inventory what the agent created: branch, workflow, subscription, resource
  group, app name, DNS target, and any state files.
- Decide whether to import live resources into Terraform or replace them.
- Move Omnipost runtime resources into Omnipost Terraform.
- Remove Bicep only after Terraform parity and a successful apply.

Exit criteria:

- Live target is known and healthy.
- Terraform owns Omnipost resources without Bicep or agent drift.

## Phase 8: Shared Data Plane

Owner: `neuralliquid-org`; tenant schemas owned by the products

Convolens and House of Veritas share one PostgreSQL server, `nl-prod-shared-pg`,
created with `az` on 2026-08-06 and belonging to no state. It cannot live in
either product's Terraform without recreating the guest relationship the move
was meant to remove, so it is org-owned. See
[ADR 0002](../adr/0002-shared-data-plane-ownership.md).

- Codify the server, resource group, firewall, server parameters and tenant
  databases in `infra/terraform/shared-data` using import blocks. Done; the
  first plan reads 7 to import, 1 to change (missing tags), 0 to destroy.
- Apply the import so the resources stop being drift.
- Move the shared server admin credential out of `nl-prod-convolens-kv` into an
  org-owned vault in `nl-prod-shared-rg`, and each tenant's connection string
  into that product's own vault.
- Close the default `PUBLIC` `CONNECT` grant on each tenant database, with both
  product owners, since it touches both access paths.
- Retire `nl-prod-convolens-pg` once both applications have been observed
  healthy on the shared server. It is the rollback path until then, and it is
  billing.

Exit criteria:

- The shared server is in exactly one Terraform state with a clean plan.
- No product's vault holds another product's or the org's credentials.
- The pre-consolidation server is deleted and the second bill has stopped.
