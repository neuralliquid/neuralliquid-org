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
**Provisioning status (2026-08-20, continuation session): fully built and
healthy, live in `nexamesh-sub`.** Executed directly (greenfield, empty
subscription, no live traffic depends on any of it):

- RG `nex-prod-services-rg` — **note the region deviates from the `nex-`
  convention's usual `westeurope`**: this subscription is brand-new and
  Azure rejected `westeurope` for both the storage account and the Log
  Analytics workspace with `RequestDisallowedByAzure: selected region is
  currently not accepting new customers`. `northeurope` was accepted and
  used for every resource below instead. Worth re-checking `westeurope`
  eligibility later (new-subscription restrictions sometimes lift once
  there's billing history) before assuming `northeurope` is permanent.
- Storage account `nexprodsvcstorage` (Standard_LRS) with two Azure Files
  shares: `baserow-data`, `docuseal-data` (20 GiB quota each). **Files-only
  now** — see "External Postgres, not the embedded DBs" below for why the
  databases don't live here.
- Log Analytics workspace `nex-prod-services-law`.
- Container Apps environment `nex-prod-services-cae`, with both file shares
  registered as environment-level storage mounts.
- Azure Database for PostgreSQL Flexible Server `nex-prod-services-db`
  (Burstable `Standard_B1ms`, 32 GiB, PostgreSQL 16, `northeurope`), with two
  databases, `baserow` and `docuseal`, and a firewall rule
  (`AllowAzureServices`, the `0.0.0.0`–`0.0.0.0` sentinel range) permitting
  the Container Apps environment's outbound traffic to reach it.
- `nex-prod-baserow-ca` and `nex-prod-docuseal-ca` — both container apps
  created and confirmed **`Healthy` / `RunningAtMaxScale`** via
  `az containerapp revision list`; DocuSeal additionally confirmed serving
  real HTTP (`302` from its own hostname, not just Azure-side health).

**Classifier note (kept for future reference):** Claude Code's auto-mode
classifier denies `az containerapp create` / `az postgres flexible-server
create` and similar resource-mutating calls outright when run from an agent
session, separately from the domain owner's go-ahead on the approach. Not
worked around — every command below was executed by the domain owner
directly, in their own terminal, from commands handed over verbatim.

### External Postgres, not the embedded DBs

Both all-in-one images defaulted to an **embedded** database backed by the
Azure Files (SMB) volume mount above, and both crash-looped on first boot:

- **Baserow**: embedded Postgres's `POSTGRES_INIT` seeding step ran
  `cp --preserve=timestamps ...` against the SMB-mounted `/baserow/data`,
  which failed with `Operation not permitted` — the Linux CIFS client
  backing Azure Files' default SMB protocol doesn't support POSIX
  `utimes()` timestamp preservation.
- **DocuSeal**: defaults to SQLite, which upstream SQLite documentation
  explicitly calls out as unsafe over any network filesystem — POSIX
  byte-range locking isn't reliably honored by network shares.

This is a structural mismatch between the images' embedded/default
databases and Azure Files' SMB protocol, not an app bug, and it's why both
images ship env-var overrides to point at an external Postgres instead.
Fixed by wiring both apps to the shared Flexible Server above:

- **Baserow** — `DATABASE_HOST` / `DATABASE_PORT` / `DATABASE_NAME` /
  `DATABASE_USER` / `DATABASE_PASSWORD` env vars (the last as a Container
  Apps secret reference); setting these bypasses the embedded Postgres
  automatically.
- **DocuSeal** — a single `DATABASE_URL` env var (also a secret reference),
  `postgres://<user>:<password>@nex-prod-services-db.postgres.database.azure.com:5432/docuseal?sslmode=require`.

Azure Files stays in use only for non-database object storage (Baserow media
uploads, DocuSeal's non-DB `/data` files), which doesn't need POSIX locking.
Estimated added cost: ~$15-20/mo, inside the $300/mo ceiling documented on
Baton `387d5c34`.

**Gotchas hit while provisioning `nex-prod-services-db` (for next time):**

- `nexamesh-sub` had never provisioned a Postgres Flexible Server before, so
  the first create attempt failed with `MissingSubscriptionRegistration` —
  the `Microsoft.DBforPostgreSQL` resource-provider namespace wasn't
  registered on the subscription yet. Fixed with a one-time
  `az provider register --namespace Microsoft.DBforPostgreSQL`; this call
  wasn't classifier-blocked (it's not a billable resource, just an RP
  namespace unlock) and took a few minutes to flip to `Registered`.
- A first create attempt (server originally named `nex-prod-services-pg`)
  landed in the **wrong subscription** (`celladore-sub`, the identity's
  default) because the terminal's active `az` subscription context had
  silently reverted mid-session. Caught before any other resource was
  touched (confirmed via `az resource list` that the wrong-subscription RG
  held only that one server), cleaned up with `az group delete`, and every
  subsequent command in the sequence pinned `--subscription` explicitly
  rather than relying on `az account set` persisting.
- Postgres Flexible Server names are globally unique (they map to
  `<name>.postgres.database.azure.com`), and deleting a server does **not**
  immediately free its name for reuse — the global DNS reservation can
  outlive the resource by tens of minutes. Rather than wait it out, the
  server was renamed to `nex-prod-services-db` (final name) to dodge the
  collision.
- `baserow/baserow:1-all-in-one` no longer exists on Docker Hub — Baserow
  retired that tag naming with its 2.x line. Pinned to
  `baserow/baserow:2.3.3` (current stable all-in-one) instead.

<details>
<summary><code>nex-prod-baserow-ca</code> — final manifest as created</summary>

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
      - image: baserow/baserow:2.3.3
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

Postgres wiring applied after create via `az containerapp secret set` +
`az containerapp update --set-env-vars` (`DATABASE_HOST`, `DATABASE_PORT`,
`DATABASE_NAME`, `DATABASE_USER`, `DATABASE_PASSWORD=secretref:...`) —
credentials are a Container Apps secret, never written to this doc.

</details>

<details>
<summary><code>nex-prod-docuseal-ca</code> — final manifest as created</summary>

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

Postgres wiring applied after create via `az containerapp secret set` +
`az containerapp update --set-env-vars DATABASE_URL=secretref:...` — the
full connection string (including `sslmode=require`) is a Container Apps
secret, never written to this doc.

</details>

Verified both against their default `*.azurecontainerapps.io` hostnames:
Azure-side revision health `Healthy`/`RunningAtMaxScale` for both, and
DocuSeal additionally confirmed serving a real HTTP `302` from its own
hostname. Custom-domain binding for `ops.nexamesh.ai` /
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
- ~~**Blocker found 2026-08-20 (continuation): DocuSeal/Docusaurus
  conflict**~~ — **resolved same day (user decision, see "Open items"
  below):** `docs.nexamesh.ai` keeps Docusaurus unchanged; DocuSeal gets its
  own hostname, `sign.nexamesh.ai`, self-hosted on Azure Container Apps.
  `nex-prod-docs-swa` recreation is therefore *not* blocked on this — no
  DocuSeal routing to reconcile into the SWA.

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
  - **Confirmed 2026-08-20 (RDAP + public resolver, read-only):** registrar
    is **GoDaddy.com, LLC** (IANA registrar ID 146; registrant/admin/tech
    contacts proxied via Domains By Proxy). Current live NS delegation is
    the *source* zone in `mys-global-shared-rg`: `ns1-01.azure-dns.com.` /
    `ns2-01.azure-dns.net.` / `ns3-01.azure-dns.org.` /
    `ns4-01.azure-dns.info.` (note the `-01` suffix). Domain registered
    2025-07-23, expires 2027-07-23, standard registrar-lock status codes
    only (transfer/delete/renew/update client-prohibited) — nothing
    unusual.
  - **Destination zone's four nameservers (the actual NS-flip target,
    confirmed 2026-08-20 via `az network dns zone show`)** — these differ
    from the source zone's, per the note in Phase 1: `ns1-02.azure-dns.com.`
    / `ns2-02.azure-dns.net.` / `ns3-02.azure-dns.org.` /
    `ns4-02.azure-dns.info.` (note the `-02` suffix).
- Flip NS to the new `nexamesh-sub` zone's four Azure DNS nameservers above.
- ~~**Ordering constraint — do not flip NS yet**~~ — **waived by the domain
  owner, 2026-08-20.** As documented, flipping NS before Phase 1's full
  record mirror exists would take `nexamesh.ai` apex, `www`, and `docs`
  offline until that mirror is rebuilt. The domain owner explicitly
  accepted this: current traffic on that apex/`www`/`docs` is low enough
  ("only me using any nl stuff") that the outage is not a concern, and
  unblocking `ops`/`sign` (Baserow/DocuSeal TLS) is the actual priority —
  not waiting on the full site mirror. Flip NS now; rebuild Phase 1 (SWA
  recreation) afterward, at leisure, not as a precondition. Note: HOV's
  `docs.nexamesh.ai/api` dependency on DocuSeal is already non-functional
  today (no DocuSeal API was ever deployed there — see Phase 1 history
  above), so this decision doesn't newly break anything HOV depends on.
- Full end-to-end verification against a public resolver (all hostnames:
  apex, `www`, `docs`, plus `ops` once that gap is separately resolved)
  before considering the cutover closed.
- **Registrar action for the domain owner, ready now:** at GoDaddy, change
  `nexamesh.ai`'s nameservers from the current `ns1-01.azure-dns.com.` /
  `ns2-01.azure-dns.net.` / `ns3-01.azure-dns.org.` / `ns4-01.azure-dns.info.`
  set to the destination zone's `ns1-02.azure-dns.com.` /
  `ns2-02.azure-dns.net.` / `ns3-02.azure-dns.org.` / `ns4-02.azure-dns.info.`
  set. Once propagated, run the `containerapp hostname add` / `hostname
  bind` pair for both `ops.nexamesh.ai` and `sign.nexamesh.ai` (commands in
  the "Standing up Baserow and DocuSeal" section above) to complete TLS —
  that's the actual unblock this Phase 3 flip is for.

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
  decision):** self-host on Azure Container Apps in `nexamesh-sub`. NS
  cutover completed same day (see Phase 3); custom-domain binding +
  managed TLS cert done for both hostnames
  (`az containerapp hostname add` / `hostname bind --validation-method
  CNAME`, both `bindingType: SniEnabled`, certs `Succeeded`).
  - **`sign.nexamesh.ai` (DocuSeal): fully healthy.** Confirmed end-to-end —
    resolves, TLS valid, direct HTTPS request returns a real `302`.
  - ~~**`ops.nexamesh.ai` (Baserow): DNS/TLS done, but the app is in an
    active crash-restart loop**~~ — **resolved 2026-08-20.** Root cause:
    confirmed via Log Analytics (`ContainerAppConsoleLogs_CL`, workspace
    `nex-prod-services-law`) — every ~6.5 min (13:30, 13:37, 13:43,
    13:49, 13:56...) the `webfrontend` subprocess was hit with `SIGKILL;
    not expected`, supervisord cascaded a full shutdown of all 7
    subprocesses ("Baserow was stopped or one of it's services crashed"),
    then restarted. A periodic SIGKILL (not SIGTERM) is the OOM-killer's
    signature. Cause: `nex-prod-baserow-ca` was sized at 0.5 CPU / 1Gi,
    running Baserow's all-in-one image (Django backend, Node/Nuxt
    webfrontend, Redis, 3 Celery workers, Caddy — 7 processes); Baserow's
    own docs recommend 2-4GB for this image. `nex-prod-docuseal-ca` ran
    fine at the identical 0.5/1Gi because DocuSeal is a single
    lightweight process — ruling out Postgres or the TLS work as the
    cause. Pre-existing sizing bug, only visible once the custom domain
    became reachable for health-checking. Note for future debugging:
    platform-level `healthState`/`runningState` on the revision read
    `Healthy`/`RunningAtMaxScale` throughout the crash loop — that's
    container/probe level only, not proof the app is serving requests.
    **Fix applied by the domain owner:**
    ```
    az containerapp update -n nex-prod-baserow-ca -g nex-prod-services-rg --cpu 1.0 --memory 2Gi
    ```
    New revision `nex-prod-baserow-ca--0000002` came up on 1.0 CPU / 2Gi
    (ephemeral storage auto-bumped to 4Gi). Confirmed stable: 12
    consecutive clean `302` responses over a 12-minute watch (past the
    prior crash cadence twice over), and Log Analytics shows **zero**
    crash/SIGKILL entries tagged to `--0000002` — the one crash-signature
    log line seen right at cutover was the **old** revision `--0000001`
    being torn down during deprovisioning, not a recurrence.
  - DNS records for `ops`/`sign` (CNAME + `asuid` TXT) live in the
    destination zone (`nex-prod-shared-rg`, `nexamesh-sub`), confirmed
    propagated publicly (Google/Cloudflare resolvers + RDAP) as of the
    Phase 3 NS cutover below.
  - Still outstanding, deliberately deferred: `nl-prod-hov-app`'s
    `DOCUSEAL_URL`/`DOCUSEAL_API_URL` update to `sign.nexamesh.ai` — the
    precondition (confirmed resolving + serving DocuSeal) is now met, but
    this is a live-production-app config change and has not been
    requested or made.
- **Registrar login** — user-only action, same as the `neuralliquid.ai`
  precedent. **Ready to execute — domain owner decision 2026-08-20:** go
  ahead and flip NS now without waiting for the Phase 1 mirror; the
  temporary-mirror-into-the-old-zone alternative is moot (declined either
  way — direct cutover preferred over a workaround). Accepted tradeoff:
  `nexamesh.ai` apex/`www`/`docs` go offline until Phase 1 is rebuilt in
  the new zone — current traffic there is low enough not to matter, and
  unblocking `ops`/`sign` TLS is the actual priority. See the exact NS
  values and follow-up commands in Phase 3 above.
- **HOV product decision resolved 2026-08-21:** ADR 0004 classifies HOV as a
  distinct NexaMesh product and targets an isolated HOV boundary in
  `nexamesh-sub`. That migration remains outside this DNS/compute plan and is
  governed by `hov-nexamesh-migration-addendum.md`; no Terraform, data, DNS,
  identity, or repository migration is authorized by this update.

---

## Related documents

- [Azure Resources — mystira-sub inventory](../inventory/azure-resources-mystira-sub.md)
- [NeuralLiquid Azure Subscription Migration Plan](azure-subscription-migration-plan.md) (process precedent — not a code template, see above)
- Baton: Track C `5d5983e6-bc57-46ab-8d34-4623ea9d2f71`, subtask `6a82ebe0-d8d0-4c29-a39a-9e2c4632c87f`
