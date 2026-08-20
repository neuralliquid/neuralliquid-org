# nexamesh.ai Azure Subscription Migration Plan

**Status:** Baton subtask created (`6a82ebe0-d8d0-4c29-a39a-9e2c4632c87f`, under
Track C `5d5983e6-bc57-46ab-8d34-4623ea9d2f71`)
**Priority:** High
**Goal:** Migrate `nexamesh.ai`'s DNS zone and compute from the shared/legacy
`mystira-sub` into the dedicated `nexamesh-sub`, created 2026-08-20 for
exactly this purpose. This is **Azure → Azure**, not Azure → Cloudflare —
see "Why not the `neuralliquid.ai` Terraform template" below before assuming
any code here is reusable verbatim.

---

## Strategic context

`nexamesh.ai` (Nexamesh, personal IP, unrelated to NeuralLiquid — see the
ownership boundary note below) currently lives entirely on `mystira-sub`,
the same shared/legacy subscription NeuralLiquid's Track B migration exists
to get off of. The user's explicit decision (2026-08-20): a dedicated Azure
subscription in the Celladore tenant (`nexamesh-sub`,
`8a5dc70a-bafa-4a04-a281-9b4862a70810`), not Cloudflare and not folded into
`neuralliquid-sub`. `nexamesh-sub` and its GitHub counterpart `nexamesh-org`
were created that session; this plan covers the still-outstanding cutover of
what actually runs there.

**Ownership boundary** (Baton `387d5c34`): Nexamesh must not be placed into
any NeuralLiquid product slot. A dedicated subscription inside a tenant that
also hosts `neuralliquid-sub` is a billing/hosting fact, not a product claim
— confirmed not to conflict with that ruling. Correspondingly, this plan is
its own document rather than a section appended to
`azure-subscription-migration-plan.md`.

---

## Why not the `neuralliquid.ai` Terraform template

The prior handoff suggested mirroring "whatever Terraform stood up
`nl-global-shared-rg`" (Track B Subtask 3, `ab1e7ce6`). Checked directly
2026-08-20 — that's not a usable template, for two independent reasons:

1. **It was never actually applied.** `infra/terraform/dns/variables.tf`
   and `backend.tf` both note the module's own remote-state backend
   (`nlorgtfstate`, in `nl-org-tfstate-rg`) lives on `mystira-sub`
   (`bb4e3882-...`) — the same legacy subscription the whole migration
   exists to get away from. The live `nl-global-shared-rg` zone was built
   by direct `az` CLI calls; Terraform `import` blocks were retrofitted
   afterward so a *future* `terraform apply` would adopt the records, not
   so this module could be run to reproduce them elsewhere.
2. **Its own final destination was superseded the same day.** Per
   `docs/plans/azure-subscription-migration-plan.md` §Subtask 3: the
   `nl-global-shared-rg` Azure zone was explicitly decided against as the
   live delegation target (Azure DNS lock-in was the original failure mode
   being fixed) and the registrar was pointed at Cloudflare instead. The
   Azure zone in `neuralliquid-sub` survives only as a rollback/reference
   copy, and its own Terraform (PR #7) is "kept as documented rollback
   infra," not the live IaC path.

**What *is* reusable is the process**, and it happens to validate the
cross-tenant-credential constraint below independently: `mys-global-shared-rg`
(source) and `nl-global-shared-rg` (that migration's Azure-side destination)
are on two different subscriptions in two different tenants under two
different identities — exactly the same shape as `mystira-sub` →
`nexamesh-sub`. That migration handled it by never attempting a single
unified `terraform apply`; it captured live records via direct DNS query,
recreated them in the destination via `az` CLI under the destination's own
credential, verified against the destination zone's own nameservers, and
only did the registrar NS flip once the destination was independently
confirmed correct. This plan follows the same shape.

---

## Current state (live-audited 2026-08-20)

**Source side — `mystira-sub` (`bb4e3882-2079-4bab-8974-611bc0b8bb58`,
tenant `9530cd32`, identity `jurie@phoenixvc.tech`):**

- `nex-prod-shared-rg` — exactly 2 resources:
  - `nex-prod-marketing-swa` (Free tier, `westeurope`, GitHub-connected to
    `Nexamesh/nexamesh-core`, branch `main`). Custom domains `nexamesh.ai`
    and `www.nexamesh.ai`, both status **Ready**. `defaultHostname`:
    `jolly-beach-01f60a803.7.azurestaticapps.net`.
  - `nex-prod-docs-swa` (Standard tier, `westeurope`, provider `SwaCli` —
    not GitHub-connected, deployed some other way, unconfirmed how).
    Custom domain `docs.nexamesh.ai` status **Failed** since 2026-08-12
    ("An unknown error has occurred while adding your custom domain") — no
    TLS cert was ever issued. `defaultHostname`:
    `ashy-bay-0136c8003.7.azurestaticapps.net`. Root cause of the
    HTTPS-connection-fails symptom Track C had mis-recorded as "DNS
    NXDOMAIN" — DNS is fine, this binding failure is the actual fault.
- `nexamesh.ai` DNS zone — lives in `mys-global-shared-rg` (a *different*
  RG, shared with `phoenixvc.tech` and `mystira.app`, neither of which
  moves — do not migrate this RG wholesale). Confirmed genuinely
  authoritative (public NS matches registrar). Records: apex `A` (Azure
  alias record → `nex-prod-marketing-swa` resource directly, not a
  hostname CNAME), `www` CNAME → `jolly-beach-01f60a803...`, `docs` CNAME →
  `ashy-bay-0136c8003...`, 2 TXT (`openai-domain-verification`, one opaque
  verification token), NS, SOA. **No `ops.nexamesh.ai` record exists** —
  public NXDOMAIN, not in the Azure zone either. `nl-prod-hov-app` (a
  NeuralLiquid/HOV workload, per the mystira-sub inventory doc) has a
  Baserow integration pointing at `https://ops.nexamesh.ai` — either that
  hostname was never provisioned or HOV's config is wrong. This is a
  pre-existing gap independent of the migration; flagged so the cutover
  doesn't silently carry the gap forward without someone deciding what
  `ops.nexamesh.ai` should actually point to.

**Destination side — `nexamesh-sub` (`8a5dc70a-bafa-4a04-a281-9b4862a70810`,
tenant `5384ef74` "Celladore Systems", identity `smit.jurie@gmail.com`):**
currently empty. No resource groups, no resources.

**Naming convention:** nothing in `nexamesh-sub` should carry a `mys-`
prefix — confirmed 2026-08-20 by direct check that `neuralliquid-sub` (the
prior migration's destination) carries zero `mys-`-prefixed names, only
`nl-`. Source-side Nexamesh resources already use `nex-` consistently
(`nex-prod-marketing-swa`, `nex-prod-docs-swa`, `nex-prod-shared-rg`) —
carry that prefix into the destination unchanged.

---

## The credential boundary (read this before writing any Terraform)

No single Azure identity in this workspace can see both sides of this
cutover:

| Side | Subscription | Tenant | Identity |
|------|--------------|--------|----------|
| Source | `mystira-sub` (`bb4e3882-...`) | `9530cd32-...` | `jurie@phoenixvc.tech` |
| Destination | `nexamesh-sub` (`8a5dc70a-...`) | `5384ef74-...` (Celladore) | `smit.jurie@gmail.com` |

A single `terraform apply` with one `azurerm` provider block cannot span
both. Either:

- **Option A (matches the `neuralliquid.ai` precedent):** do it by hand —
  capture live source-side state by direct query, recreate it on the
  destination side under the destination's own credential, verify
  independently, then cut over. Retrofit Terraform `import` blocks
  afterward for IaC ownership going forward, same as `infra/terraform/dns`
  did.
- **Option B:** set up a B2B guest invite so one principal spans both
  tenants, then use two `azurerm` provider aliases in one Terraform
  config. More setup cost, but enables an actual `terraform apply` /
  `plan` workflow instead of hand execution. Worth it only if this becomes
  a repeated pattern (it might, if more Nexamesh infra moves later).

No decision made yet on A vs. B — flagged as an open question on the Baton
subtask, not resolved by this document.

---

## Execution phases

### Phase 1 — Destination scaffolding
- Resource group in `nexamesh-sub`, following the `nex-` naming convention
  (e.g. `nex-prod-shared-rg`, matching the source name is fine since it's a
  different subscription).
- DNS zone `nexamesh.ai` created fresh in the destination RG (mirrors how
  `nl-global-shared-rg`'s zone was built — new zone, not a subscription
  move of the existing one).
- 2 Static Web Apps recreated: `nex-prod-marketing-swa` (re-link the
  `Nexamesh/nexamesh-core` GitHub repo, branch `main`) and
  `nex-prod-docs-swa` (deploy source unconfirmed — resolve how the current
  one is actually deployed before recreating it blind, since `SwaCli`
  provider on the source implies some out-of-band deploy tooling, not a
  GitHub Actions workflow).
- **Fix the `docs.nexamesh.ai` binding failure on the *destination* SWA
  from the start** — no reason to carry the Failed-binding bug forward into
  a fresh resource; this is a chance to not reproduce it.

### Phase 2 — Verify destination in isolation
- Every DNS record re-verified by querying the new zone's own
  nameservers directly (same rigor as the `neuralliquid.ai` migration) —
  not the public resolvers yet, since NS delegation hasn't moved.
- Custom domain bindings on both SWAs confirmed `Ready` with valid TLS
  before touching the registrar.

### Phase 3 — Registrar cutover
- Requires the domain owner's registrar login (same constraint as the
  `neuralliquid.ai` cutover — cannot be executed from an agent session).
  Confirm `nexamesh.ai`'s registrar and current NS delegation first (RDAP
  lookup), same method used for `neuralliquid.ai` (Dynadot, confirmed via
  RDAP).
- Flip NS to the new `nexamesh-sub` zone's four Azure DNS nameservers.
- Full end-to-end verification against a public resolver (all hostnames:
  apex, `www`, `docs`, plus `ops` once that gap is separately resolved)
  before considering the cutover closed.

### Phase 4 — Decommission source
- Once 24-48h of stable traffic confirmed on the new zone: remove the old
  `nex-prod-shared-rg` resources and the `nexamesh.ai` zone from
  `mys-global-shared-rg` (leave `phoenixvc.tech` and `mystira.app`
  untouched in that RG — it's permanently shared, never delete it
  wholesale).

---

## Open items / blocking

- **A vs. B credential approach** (see above) — needs a decision before
  Phase 1 starts.
- **`nex-prod-docs-swa`'s actual deploy source** — unconfirmed; needed
  before Phase 1 can recreate it correctly.
- **`ops.nexamesh.ai`** — separate investigation, not gating this
  migration, but should be resolved (or explicitly deferred) before Phase 3
  so the cutover doesn't quietly drop a hostname a live NeuralLiquid
  workload depends on.
- **Registrar login** — user-only action, same as the `neuralliquid.ai`
  precedent.

---

## Related documents

- [Azure Resources — mystira-sub inventory](../inventory/azure-resources-mystira-sub.md)
- [NeuralLiquid Azure Subscription Migration Plan](azure-subscription-migration-plan.md) (process precedent — not a code template, see above)
- Baton: Track C `5d5983e6-bc57-46ab-8d34-4623ea9d2f71`, subtask `6a82ebe0-d8d0-4c29-a39a-9e2c4632c87f`
