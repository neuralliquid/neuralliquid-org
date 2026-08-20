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
  - `nex-prod-docs-swa` (Standard tier, `westeurope`, provider `SwaCli`).
    **Deploy source resolved 2026-08-20:**
    `Nexamesh/nexamesh-core/.github/workflows/deploy-docs-azure.yml` — GitHub
    Actions, push-to-`main` + manual dispatch, builds `apps/docs`
    (Docusaurus) and deploys via SWA CLI + deployment token (not Azure's
    native GitHub-integration flow, which is why `provider` reads `SwaCli`).
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

**Recommendation (2026-08-20, continuation session): Option A.** This is a
one-time cutover, not a repeated pattern yet — the `neuralliquid.ai`
precedent used hand-execution successfully under the identical constraint,
and B2B guest setup is pure overhead unless/until more Nexamesh infra
follows. Revisit toward B only if a second migration of this shape shows up.
Not yet confirmed by the domain owner — treat as the working assumption for
Phase 1 planning, not a closed decision.

---

## Standing up Baserow (`ops.nexamesh.ai`) and DocuSeal (`docs.nexamesh.ai`)

Neither exists as real infrastructure today — confirmed above, nothing in
`mystira-sub` runs either. Both are self-hostable open-source products with
official Docker images, and both also have a SaaS option. Recommendation
below is advisory, cost-driven — not executed, needs the domain owner's
sign-off before provisioning either.

**Recommendation: self-host both, in `nexamesh-sub`, not SaaS.** Reasoning:

- **Cost.** `387d5c34` (the org-restructuring task) already documents a
  tight, explicit ceiling: Eben's real budget is $300/mo Azure + $150/mo
  GitHub, and current Mystira-side spend already exceeds it. Adding two new
  *per-seat* SaaS subscriptions on top of that is the wrong direction; a
  self-hosted pair of small Azure Container Apps is roughly a flat,
  low-tens-of-dollars monthly cost regardless of headcount, in the *new*
  `nexamesh-sub` subscription (not stacked onto Mystira's already-strained
  one). SaaS list pricing for both products changes over time — verify
  current numbers at baserow.io/pricing and docuseal.com/pricing before
  comparing, don't trust a remembered figure here.
- **Fit.** Both ship an official all-in-one Docker image
  (`baserow/baserow:1-all-in-one` bundles backend + worker + frontend +
  embedded Postgres + Caddy for TLS; `docuseal/docuseal` is a single
  container, SQLite by default, can point at Postgres). Light internal-tool
  load (one estate/ops team, not a multi-tenant SaaS) fits comfortably in a
  small Azure Container App — e.g. 0.5 vCPU / 1 GiB, min replicas 1 for
  always-on (HOV depends on both live, so scale-to-zero isn't appropriate
  here even though it's cheaper). Rough combined estimate: ~$30-70/mo for
  both, well inside a dedicated subscription's headroom — verify against
  current Azure Container Apps consumption pricing before committing to a
  number.
- **Ops trade-off, stated plainly:** self-hosting trades SaaS's zero-ops
  convenience (backups, patching, TLS renewal, uptime SLA all handled) for
  lower/flatter cost and data locality. The all-in-one images' embedded
  databases are a single point of failure unless backed by a real backup
  routine (volume snapshot, or point at Azure Database for PostgreSQL
  Flexible Server instead of the embedded DB if that matters for either
  service's data). Worth an explicit decision, not a default.
**Provisioning status (2026-08-20, continuation session): partially built,
live in `nexamesh-sub`.** Executed directly (greenfield, empty subscription,
no live traffic depends on any of it):

- RG `nex-prod-services-rg` — **note the region deviates from the `nex-`
  convention's usual `westeurope`**: this subscription is brand-new and
  Azure rejected `westeurope` for both the storage account and the Log
  Analytics workspace with `RequestDisallowedByAzure: selected region is
  currently not accepting new customers`. `northeurope` was accepted and
  used for every resource below instead. Worth re-checking `westeurope`
  eligibility later (new-subscription restrictions sometimes lift once
  there's billing history) before assuming `northeurope` is permanent.
- Storage account `nexprodsvcstorage` (Standard_LRS) with two Azure Files
  shares: `baserow-data`, `docuseal-data` (20 GiB quota each).
- Log Analytics workspace `nex-prod-services-law`.
- Container Apps environment `nex-prod-services-cae`, with both file shares
  registered as environment-level storage mounts.

**Blocked, not executed:** the final `az containerapp create` step for both
apps — Claude Code's auto-mode classifier denied the command outright (a
separate guardrail from the domain owner's go-ahead on the approach; not
worked around). Manifests below are ready to run as-is by whoever has
permission — the user directly, or a session with this action allowlisted:

<details>
<summary><code>nex-prod-baserow-ca</code> — <code>az containerapp create --yaml baserow-ca.yaml</code></summary>

```yaml
location: northeurope
resourceGroup: nex-prod-services-rg
type: Microsoft.App/containerApps
name: nex-prod-baserow-ca
properties:
  environmentId: /subscriptions/8a5dc70a-bafa-4a04-a281-9b4862a70810/resourceGroups/nex-prod-services-rg/providers/Microsoft.App/managedEnvironments/nex-prod-services-cae
  configuration:
    ingress:
      external: true
      targetPort: 80
      transport: auto
      allowInsecure: false
    activeRevisionsMode: Single
  template:
    containers:
      - image: baserow/baserow:1-all-in-one
        name: baserow
        resources:
          cpu: 0.5
          memory: 1Gi
        env:
          - name: BASEROW_PUBLIC_URL
            value: https://ops.nexamesh.ai
        volumeMounts:
          - volumeName: baserow-data
            mountPath: /baserow/data
    volumes:
      - name: baserow-data
        storageType: AzureFile
        storageName: baserow-data
    scale:
      minReplicas: 1
      maxReplicas: 1
```

</details>

<details>
<summary><code>nex-prod-docuseal-ca</code> — <code>az containerapp create --yaml docuseal-ca.yaml</code></summary>

```yaml
location: northeurope
resourceGroup: nex-prod-services-rg
type: Microsoft.App/containerApps
name: nex-prod-docuseal-ca
properties:
  environmentId: /subscriptions/8a5dc70a-bafa-4a04-a281-9b4862a70810/resourceGroups/nex-prod-services-rg/providers/Microsoft.App/managedEnvironments/nex-prod-services-cae
  configuration:
    secrets:
      - name: secret-key-base
        value: "<generate fresh — do not reuse any value written to a doc; e.g. `openssl rand -hex 64`>"
    ingress:
      external: true
      targetPort: 3000
      transport: auto
      allowInsecure: false
    activeRevisionsMode: Single
  template:
    containers:
      - image: docuseal/docuseal:latest
        name: docuseal
        resources:
          cpu: 0.5
          memory: 1Gi
        env:
          - name: SECRET_KEY_BASE
            secretRef: secret-key-base
          - name: HOST
            value: sign.nexamesh.ai
        volumeMounts:
          - volumeName: docuseal-data
            mountPath: /data
    volumes:
      - name: docuseal-data
        storageType: AzureFile
        storageName: docuseal-data
    scale:
      minReplicas: 1
      maxReplicas: 1
```

</details>

After creation: verify both against their default `*.azurecontainerapps.io`
hostnames first. Custom-domain binding for `ops.nexamesh.ai` /
`sign.nexamesh.ai` needs a DNS record — **that record has to go in the
currently-authoritative zone in `mys-global-shared-rg`** (a live-prod DNS
write, not yet confirmed) until the full zone migration below reaches Phase
3, at which point it moves with everything else. Wiring `nl-prod-hov-app`'s
`DOCUSEAL_URL`/`DOCUSEAL_API_URL` to the new `sign.nexamesh.ai` hostname
(instead of `docs.nexamesh.ai`) is a separate, later, explicitly-confirmed
step — it's a live production app's config, per the user's 2026-08-20
decision to split the two services onto separate hostnames.

- **Placement:** both belong in the *destination* (`nexamesh-sub`), as part
  of this migration's Phase 1 — not built in `mystira-sub` first and moved
  later. This also directly resolves the DocuSeal/Docusaurus hostname
  conflict above: once a real DocuSeal container exists, `docs.nexamesh.ai`
  needs either a path split (`/` → Docusaurus docs, `/api` → proxied to
  DocuSeal, via the SWA's `staticwebapp.config.json` routing) or two
  separate hostnames (e.g. move docs to `docs.nexamesh.ai` and DocuSeal to
  something like `sign.nexamesh.ai`, updating HOV's `DOCUSEAL_URL` to
  match) — the second is simpler and avoids fighting SWA route config for a
  mixed static+API origin. Flagging both options rather than picking one;
  this is the kind of call that should be made once, deliberately, not
  discovered by whichever engineer next has to debug a 404.

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
  `nex-prod-docs-swa` (deploy source **resolved 2026-08-20**:
  `Nexamesh/nexamesh-core/.github/workflows/deploy-docs-azure.yml` — push to
  `main` builds `apps/docs` and deploys via SWA CLI + a deployment-token
  secret; point that workflow's `AZURE_STATIC_WEB_APPS_API_TOKEN` at the new
  destination resource once it exists, same as re-linking the marketing
  app's GitHub connection).
- **Fix the `docs.nexamesh.ai` binding failure on the *destination* SWA
  from the start** — no reason to carry the Failed-binding bug forward into
  a fresh resource; this is a chance to not reproduce it.
- **New blocker found 2026-08-20 (continuation): resolve the
  DocuSeal/Docusaurus conflict before recreating `nex-prod-docs-swa`.**
  `nl-prod-hov-app`'s live app settings expect a **DocuSeal** e-signature
  API at `docs.nexamesh.ai/api`, but the only thing ever deployed to that
  hostname is the Docusaurus docs site above — no API surface exists there,
  and no other DocuSeal infrastructure is documented anywhere in
  `mystira-sub`. Rebuilding `nex-prod-docs-swa` as-is would faithfully
  reproduce a resource that doesn't do what HOV needs from it. Needs the
  domain owner to say which is true: (a) DocuSeal was never actually stood
  up and HOV's config is aspirational/stale, (b) DocuSeal runs elsewhere
  (self-hosted or SaaS) and only the routing was never wired up, or (c)
  something else. Don't silently pick one when scaffolding Phase 1.

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

- **A vs. B credential approach** — recommended A above; not yet confirmed
  by the domain owner.
- ~~`nex-prod-docs-swa`'s actual deploy source~~ — **resolved 2026-08-20**,
  see Phase 1 above.
- ~~DocuSeal/Docusaurus conflict at `docs.nexamesh.ai`~~ — **resolved
  2026-08-20 (user decision):** keep Docusaurus at `docs.nexamesh.ai`
  unchanged; DocuSeal gets its own new hostname, `sign.nexamesh.ai`.
- ~~`ops.nexamesh.ai` / Baserow hosting~~ — **resolved 2026-08-20 (user
  decision):** self-host on Azure Container Apps in `nexamesh-sub`.
  Partially provisioned — see "Standing up Baserow and DocuSeal" above for
  exact state and what's still blocked.
- **Registrar login** — user-only action, same as the `neuralliquid.ai`
  precedent.
- **New, larger question raised 2026-08-20 (user, mid-session):** should
  `nl-prod-hov-app` (HOV) itself move from `neuralliquid-sub`/NeuralLiquid
  into `nexamesh-sub`/`nexamesh-org`, given its only two non-Mystira runtime
  dependencies are both Nexamesh's own services (Baserow, DocuSeal)? This is
  a separate, larger-scope question than this document's DNS/compute
  cutover — tracked as an open decision on Baton task `387d5c34` rather than
  folded into this plan. See that task before assuming HOV stays put.

---

## Related documents

- [Azure Resources — mystira-sub inventory](../inventory/azure-resources-mystira-sub.md)
- [NeuralLiquid Azure Subscription Migration Plan](azure-subscription-migration-plan.md) (process precedent — not a code template, see above)
- Baton: Track C `5d5983e6-bc57-46ab-8d34-4623ea9d2f71`, subtask `6a82ebe0-d8d0-4c29-a39a-9e2c4632c87f`
