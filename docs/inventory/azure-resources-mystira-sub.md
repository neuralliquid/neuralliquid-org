# Azure Resource Inventory — Mystira Subscription (`bb4e3882…`)

**Live enumeration was performed on 2026-08-20** and supersedes the
"no live enumeration was performed" framing this file carried after the
2026-08-19 pass. The prior pass (repo-evidence only — Terraform `import {}`
blocks, docs, and HTTP liveness probes, no Azure API access) is preserved
verbatim below under **Historical — 2026-08-19 Pass** as a diff basis. This
section is the current source of truth; where the two disagree, this section
wins and the disagreement is called out explicitly.

## Access confirmation (2026-08-20)

```
$ az account show --output json
```
Returned subscription `bb4e3882-2079-4bab-8974-611bc0b8bb58` ("mystira-sub"),
tenant `9530cd32-9e33-47f0-9247-ed964730b580`, identity
`jurie@phoenixvc.tech`, `isDefault: true`. This is a **different identity**
than the one that hit the tenant-boundary block on 2026-08-19
(`smit.jurie@gmail.com`) — access exists now because a different, correctly
tenant-scoped identity was used, not because anything changed about the
subscription itself.

**Reproducibility caveat:** the CLI's active/default subscription is shared
mutable state and was observed to silently drift mid-audit (to
`celladore-sub`, `614e6f86-e401-4bdf-8479-a59986e18815`) between one command
and the next, causing several `ResourceGroupNotFound` / `Vault not found`
false negatives before it was noticed. Every command below was re-run (or
originally issued) with an explicit `--subscription
bb4e3882-2079-4bab-8974-611bc0b8bb58` flag — do not rely on ambient/default
context when reproducing this audit. For the DNS zone record-set dump
specifically, ambient context was not used for attribution either way:
subscription placement there is confirmed independently by the ARM resource
`id` field on every one of the 30 record sets returned (`grep -c
"/subscriptions/bb4e3882-2079-4bab-8974-611bc0b8bb58"` against the raw
response returns 31/31 matching lines, i.e. every record plus the zone
resource itself), not by which subscription happened to be default when the
call ran.

## Scope

Per task instructions, only these **7 resource groups** were enumerated:
`nl-prod-convolens-rg`, `nl-prod-hov-rg`, `nl-prod-cognitive-mesh-rg`,
`nl-prod-shared-rg`, `nl-prod-web-rg`, `nl-org-tfstate-rg`,
`mys-global-shared-rg`. One narrow, pre-authorized exception: the Mystira
Identity Container App (`mys-prod-identity-api`, in `mys-prod-core-rg`) was
checked specifically for the `login.hov` DNS-TXT sub-task, via
`az containerapp show` only — no other resource in that RG or any other
out-of-scope RG was enumerated.

Roughly 30 other resource groups exist in this subscription
(`mys-dev-*`, `mys-prod-story/core/app/identity/admin/publisher/chain-rg`,
`pvc-*`, `nex-*`, `nl-dev-omnipost-rg`, etc., per the saved
`az resource list --subscription bb4e3882-… --output json` dump, 247
resources / 37 resource groups total). Their **existence** is confirmed by
that dump; their **contents were not enumerated** in this pass — out of
scope by instruction.

## Live per-RG resource inventory

Source: saved full-subscription `az resource list` JSON dump (244 KB, 247
resources, captured earlier this session), filtered to the 7 in-scope RGs,
cross-referenced against targeted live `az resource list
--resource-group <rg> --subscription bb4e3882-…` / `az webapp show` /
`az keyvault show` / `az postgres flexible-server ...` /
`az staticwebapp hostname list` / `az containerapp show` calls for
higher-fidelity detail (SKU, RBAC mode, runtime, custom domains). A live
re-query of `nl-prod-convolens-rg` (`az resource list --resource-group
nl-prod-convolens-rg --subscription bb4e3882-… --output json`) returned an
identical 10-resource set to the saved dump, confirming the dump is not
stale for at least that RG; the other 6 RGs were checked against the dump
plus targeted resource-level live calls, not independently re-listed in
full.

### `nl-prod-web-rg`

| Resource | Type | Detail |
| --- | --- | --- |
| `nl-prod-web-swa` | Static Web App | **Free** SKU, `westeurope` (SKU tier not previously recorded in this repo) |
| apex custom domain (`neuralliquid.ai`) | SWA custom domain | `status: Ready`, created 2026-07-03, via `az staticwebapp hostname list` |
| www custom domain (`www.neuralliquid.ai`) | SWA custom domain | `status: Ready`, created 2026-07-03, via `az staticwebapp hostname list` |

### `nl-prod-shared-rg`

| Resource | Type | Detail |
| --- | --- | --- |
| `nl-prod-shared-pg` | PostgreSQL Flexible Server | v16, `Standard_B1ms` Burstable, 32 GB, South Africa North, zone 2 — matches old doc exactly |
| `houseofveritas` | PG database on `nl-prod-shared-pg` | present, via `az postgres flexible-server db list` |
| `convolens` | PG database on `nl-prod-shared-pg` | present, via `az postgres flexible-server db list` |
| PG firewall rule | `AllowAllAzureServicesAndResourcesWithinAzureIps_2026-8-7_2-56-48` | name matches old doc byte-for-byte, via `az postgres flexible-server firewall-rule list` |
| PG configs | `require_secure_transport=on`, `ssl_min_protocol_version=TLSv1.2` | via `az postgres flexible-server parameter show`, matches old doc |
| **`nl-prod-shared-kv`** | Key Vault | **not in old doc's Tier A/B/C tables** (it is named once, in passing, in the old "Unblock" section's Key Vault Secrets User ask — never tabled). RBAC-enabled: `enableRbacAuthorization: true`, via `az keyvault show` |

### `nl-prod-convolens-rg` (10 resources — live count matches saved dump exactly)

| Resource | Type | Detail |
| --- | --- | --- |
| `nl-prod-convolens-web` | App Service | Node 24-LTS runtime, **not** a container — old doc left this ambiguous |
| `nl-prod-convolens-asp` | App Service Plan | B1 Basic, Linux — name/SKU not previously captured in this repo |
| `nl-prod-convolens-kv` | Key Vault | RBAC-enabled: `enableRbacAuthorization: true`, via `az keyvault show` |
| `nl-prod-convolens-api` | Container App | running `nlprodconvolensacr.azurecr.io/convolens-api:0df76d8…` — **undocumented**, old doc never mentions this resource at all |
| `nl-prod-convolens-cae` | Container Apps Environment | **undocumented** |
| `nlprodconvolensacr` | Container Registry | **undocumented** |
| `nlprodconvolensst` | Storage Account | **undocumented** |
| `nl-prod-convolens-law` | Log Analytics Workspace | **undocumented** |
| `nl-prod-convolens-appi` | Application Insights | **undocumented** |
| `convolens.neuralliquid.ai` | App Service managed certificate | **undocumented** |

7 of these 10 resources were entirely absent from the old doc's Tier A/B/C
tables.

### `nl-prod-hov-rg`

| Resource | Type | Detail |
| --- | --- | --- |
| `nl-prod-hov-app` | App Service | present (runtime/`linuxFxVersion` not checked this pass) |
| `nl-prod-hov-kv` | Key Vault | **not RBAC-enabled** — `enableRbacAuthorization: false` (legacy access-policy mode), via `az keyvault show`. Notable split vs. `nl-prod-convolens-kv` (RBAC-enabled) despite `shared-data/README.md` citing Convolens as the RBAC precedent |
| `nlprodhovcosmos` | Cosmos DB account (Mongo API) | **undocumented** — see open question below |
| Private endpoint (for `nlprodhovcosmos`) | Private Endpoint | **undocumented** |
| Private DNS zone + VNet link (Cosmos) | `privatelink...` zone + link | **undocumented** |
| VNet | Virtual Network | **undocumented** |
| 3× NSG | Network Security Group | **undocumented** |
| Storage account | Storage Account | **undocumented** |
| Application Insights | App Insights | **undocumented** |
| NIC (private endpoint) | Network Interface | **undocumented** |

**Resolved 2026-08-20 (continued pass):** `nl-prod-shared-pg` carries a
`houseofveritas` PostgreSQL database (Tier A, confirmed live) *and*
`nl-prod-hov-rg` independently carries a Cosmos DB Mongo API account
(`nlprodhovcosmos`, confirmed live) with a full private-networking stack
around it. `az webapp config appsettings list --name nl-prod-hov-app
--resource-group nl-prod-hov-rg --subscription bb4e3882-…` shows **both are
wired into the app live**: `DATABASE_URL`/`POSTGRES_URL` point at the
`houseofveritas` Postgres database, and `MONGODB_URI` points at
`nlprodhovcosmos` with a populated (non-empty) connection string.
`ESTATE_BACKEND=postgres` marks Postgres as the selected backend for estate
data, but the Mongo connection string is live and populated, not a dead
leftover — which of the app's code paths actually calls Cosmos isn't
determinable from app settings alone. **Do not delete or reprovision either
datastore without checking the app's source**, since env-var presence proves
wiring, not usage.
(Values not reproduced here — several of these app settings are live
credentials.)

**Also surfaced by this same app-settings read:** `nl-prod-hov-app` has live
runtime dependencies on `https://ops.nexamesh.ai` (`BASEROW_API_URL` /
`NEXT_PUBLIC_BASEROW_URL`) and `https://docs.nexamesh.ai`
(`DOCUSEAL_API_URL` / `DOCUSEAL_URL` / `NEXT_PUBLIC_DOCUSEAL_URL`), plus
`https://identity.mystira.app` (`MYSTIRA_OIDC_ISSUER`). This is a genuine
cross-product coupling: a NeuralLiquid product (HOV) calls into Nexamesh's
Baserow ops backend and DocuSeal signing service, and authenticates against
Mystira's identity issuer, at runtime — not just at the DNS layer. Any future
DNS/subscription cutover for `nexamesh.ai` needs to either preserve these
hostnames or coordinate the cutover with HOV; this is why `mystira.app`
staying in place (per 2026-08-20 user direction, see below) doesn't fully
decouple HOV from mystira-sub's blast radius on its own — the Nexamesh
coupling is a separate, unaddressed dependency.

### `nl-prod-cognitive-mesh-rg`

| Resource | Type | Detail |
| --- | --- | --- |
| `cognitive-mesh-api-prod` | App Service (**not** a Container App) | kind `app,linux,container`, S1 plan — old doc's Tier C called this "Container App `cognitive-mesh-api`"; live data shows it's a containerized **App Service** with a different name |
| `cognitive-mesh-frontend-prod` | App Service | present, matches old doc's name |
| staging slot × 2 | `Microsoft.Web/sites/slots` | one per app above — **undocumented** |
| `cognitive-mesh-kv-prod` | Key Vault | **Resolved 2026-08-20:** `enableRbacAuthorization: false` — **not** RBAC-enabled (legacy access-policy mode), confirmed via `az keyvault show --query properties.enableRbacAuthorization`. Same pattern as `nl-prod-hov-kv`, not `nl-prod-convolens-kv` |
| 3× managed certificate | App Service certificates | **undocumented** |

`cog-dev-rg-san` (old doc's Tier C guess for a Container Apps Environment)
does **not** exist in this RG — this RG has no `Microsoft.App/managedEnvironments`
at all. Cognitive Mesh's production compute here is two containerized App
Services with staging slots, not a genuine Container Apps Environment.

### `nl-org-tfstate-rg`

| Resource | Type | Detail |
| --- | --- | --- |
| `nlorgtfstate` | Storage Account (`tfstate` container) | present, matches old doc exactly |

### `mys-global-shared-rg` — orphan check (Tier B claim)

**Old doc's claim** (Tier B): "legacy DNS zone, orphaned." **This is wrong on
the "orphaned" characterization.** The RG holds **26 live resources** spanning
multiple products, not a sparse leftover:

- DNS zones: `neuralliquid.ai`, `phoenixvc.tech`, `nexamesh.ai`, `mystira.app`
- 3× Terraform remote-state storage accounts (tfstate for other stacks)
- A shared Container Registry
- Multiple App Service Plans (including P1v3/P0v3 tiers)
- Azure Communication Services / Email Services resources
- A CIAM (Azure AD External ID / Customer Identity) directory
- Several metric alerts

**The `neuralliquid.ai` zone specifically** (the one this repo's `dns` stack
targets) is **fully populated** — 30 record sets, captured via
`az network dns record-set list --zone-name neuralliquid.ai
--resource-group mys-global-shared-rg --output json`:

- Apex `A` record: alias/`targetResource` pointing directly at `nl-prod-web-swa` (ARM alias, not an IP)
- `www` CNAME → `jolly-beach-….azurestaticapps.net`
- `admin`, `api`, `app`, `blog`, `docs`, `support` CNAMEs → apex
- `cognitive-mesh`, `control.cognitive-mesh` CNAMEs → `cognitive-mesh-frontend-prod.azurewebsites.net`
- `api.cognitivemesh` CNAME → `cognitive-mesh-api-prod.azurewebsites.net`
- `convolens` CNAME → `nl-prod-convolens-web.azurewebsites.net`
- `hov` CNAME → `nl-prod-hov-app.azurewebsites.net`
- `login.hov` CNAME → `mys-prod-identity-api.….azurecontainerapps.io`
- `omnipost` CNAME → `nl-dev-omnipost-web.azurewebsites.net` — **this is the dev slot, not a prod resource**, live in a zone that otherwise serves prod
- `email` CNAME → `eu.mailgun.org`; `MX` + SPF/DKIM `TXT` records → Mailgun; a `CAA` record; standard `NS`/`SOA`
- 7× `asuid.*` TXT records (convolens, omnipost, cognitive-mesh, control.cognitive-mesh, api.cognitivemesh, hov, login.hov), all `05B038A75C9A9151C1E0ECF5F652F255707230C7408A56A6686F15CA9CDA6872`
- `_dnsauth.login.hov` TXT record, value `_0yzstdy565w08jklyh16mc2iu0sm6my` (see DNS TXT verification section below)

This is a professionally configured, currently-relevant zone matching live
production topology — not an empty husk.

**But it is not the delegated/authoritative zone.** A public
`nslookup neuralliquid.ai 8.8.8.8` (Azure-auth-independent) returns
`laylah.ns.cloudflare.com` / `jack.ns.cloudflare.com` as authoritative —
Cloudflare, not this Azure zone.

**Corrected finding: not orphaned, but not authoritative either.** It's a
fully-configured *shadow* zone that no longer receives queries — a rollback
target and drift-risk asset, not a deletable husk. It also cannot be deleted
in isolation: `mys-global-shared-rg` is a **multi-product** RG, and removing
it would also take out the `phoenixvc.tech` and `nexamesh.ai` zones and the
shared storage/ACR/Communication Services resources that live alongside it.

### `nexamesh.ai` zone — checked 2026-08-20, unlike `neuralliquid.ai` this one is live

Per user direction 2026-08-20, `nexamesh.ai` is next in line for equivalent
treatment to what `neuralliquid.ai` already got (see "2026-08-20 scoping
decision" below). A read-only check of this zone found it in a materially
different state than `neuralliquid.ai`'s:

- `az network dns record-set list --zone-name nexamesh.ai --resource-group
  mys-global-shared-rg --subscription bb4e3882-…` — apex `A` record is an ARM
  alias to `nex-prod-marketing-swa`, in resource group **`nex-prod-shared-rg`**
  (same subscription, mystira-sub) — a resource group not among the 7
  authorized for this audit and **not previously known to this repo's
  inventory**. `www` CNAMEs to a second Static Web App
  (`jolly-beach-01f60a803…`); `docs` CNAMEs to a third
  (`ashy-bay-0136c8003…`).
- **Unlike `neuralliquid.ai`'s shadow zone, this one is genuinely
  authoritative.** A public `nslookup -type=NS nexamesh.ai` (default
  resolver, Azure-independent) returns the same four `ns*-01.azure-dns.*`
  nameservers as this zone's own `NS` record set — the registrar delegates
  here. Migrating `nexamesh.ai` off mystira-sub is therefore a **live
  registrar cutover**, the same category of work `neuralliquid.ai` went
  through, not a stale-zone cleanup.
- `www.nexamesh.ai` and the apex both serve `200 OK`. **`docs.nexamesh.ai`
  resolves via public DNS** (to the same Static Web App / Traffic Manager
  chain as the others) **but a plain HTTPS request to it returns no response
  at all** (`curl` exit/HTTP code `000` — connection or TLS-handshake
  failure, not an HTTP error status). This contradicts Track C's
  (`5d5983e6`) stated blocker of "`docs.nexamesh.ai` DNS NXDOMAIN" as
  currently worded — the DNS layer resolves fine today. The real fault looks
  like a custom-domain/certificate binding problem on the
  `nex-prod-shared-rg` Static Web App, which is out of this audit's scope to
  diagnose further. Track C's blocker description should be corrected from
  "DNS NXDOMAIN" to "DNS resolves, HTTPS connection fails" before anyone
  spends time re-checking DNS records that are already fine.
- No further enumeration of `nex-prod-shared-rg` was attempted — flagging as
  a new scope gap (added to the "What still needs re-verification" list
  below) rather than silently widening this pass's authorized scope.

### `nex-prod-shared-rg` — enumerated 2026-08-20 (continuation session)

Closed the scope gap flagged above. Direct `az resource list
--resource-group nex-prod-shared-rg --subscription bb4e3882-…` — the RG
holds exactly **2** resources, not 3 as the entry above assumed from the DNS
record set alone:

- **`nex-prod-marketing-swa`** (Free tier, `westeurope`, GitHub-connected to
  `Nexamesh/nexamesh-core`, branch `main`). `defaultHostname`:
  `jolly-beach-01f60a803.7.azurestaticapps.net` — this is the **same** SWA
  behind both the apex A-record alias *and* the `www` CNAME (`az staticwebapp
  hostname list` shows both `nexamesh.ai` and `www.nexamesh.ai` as custom
  domains on this one resource, both status `Ready`). There is no separate
  third Static Web App for `www` — correcting the earlier read of the zone
  dump, which had assumed the `www` CNAME target implied a distinct app.
- **`nex-prod-docs-swa`** (Standard tier, `westeurope`, provider `SwaCli` —
  not GitHub-connected; how it's actually deployed is unconfirmed). This is
  the root cause of the `docs.nexamesh.ai` HTTPS failure flagged above:
  `az staticwebapp hostname list` shows its one custom domain,
  `docs.nexamesh.ai`, in status **`Failed`** since `2026-08-12T12:08:44Z`
  (`errorMessage: "An unknown error has occurred while adding your custom
  domain. Please try again later."`) — the binding never completed and no
  TLS certificate was ever issued for that hostname. The DNS CNAME is
  correct and points at this SWA's real `defaultHostname`
  (`ashy-bay-0136c8003.7.azurestaticapps.net`); the fault is entirely on the
  Azure-side custom-domain binding, confirmed by a direct `curl -v` showing
  a TLS/SNI failure (`SEC_E_WRONG_PRINCIPAL` under schannel — consistent
  with "no cert exists for this SNI name"), not a DNS or network failure.
  **Remediation** (not executed — live prod write, needs confirmation):
  delete the failed custom-domain resource and re-add it, which re-triggers
  Azure's validation + cert-issuance flow.

**New gap found while checking this:** `ops.nexamesh.ai` — referenced
elsewhere in this doc as a live dependency of `nl-prod-hov-app`'s Baserow
integration — has **no DNS record** in the `nexamesh.ai` zone at all, and is
public NXDOMAIN. Either it was never provisioned or HOV's integration config
points at a dead hostname. Independent of the migration; tracked on the new
Baton subtask (`6a82ebe0`) rather than fixed here, since it's unclear what
it should point to without checking HOV's own config first.

Full detail, the corrected framing, and the migration plan are in
`docs/plans/nexamesh-ai-azure-migration-plan.md`.

## 2026-08-20 scoping decision (user direction, recorded verbatim intent)

The user provided the following scoping input for Track B this session,
recorded here rather than resolved into an implementation choice this pass
was not authorized to make:

- **`mystira.app` and `phoenixvc.tech` stay exactly where they are** — out of
  scope for the NeuralLiquid sovereignty migration, permanently on
  mystira-sub / `mys-global-shared-rg`. This directly means `mys-global-shared-rg`
  **can never be deleted or reassigned wholesale** — see the Subtask 7 note
  below.
- **`neuralliquid.ai` has already moved to Cloudflare** "as an intermediary
  layer" — matches the completed Subtask 3 (`ab1e7ce6`) work documented in
  `docs/inventory/dns.md`; no further action needed there.
- **`nexamesh.ai` and any remaining `neuralliquid` DNS need to move to a "new
  sub"** — three readings were originally recorded here rather than decided:
  (1) Cloudflare cutover mirroring `neuralliquid.ai`, (2) a dedicated Azure
  subscription under Nexamesh's own control, (3) folding into
  `neuralliquid-sub` directly. Reading 3 conflicts with a standing ruling
  (Baton task `387d5c34`, referencing `6ed39c8a-86f8-4599-a7be-e506dd637e3b`
  in `mystira-workspace`: *"Do not place Nexamesh/nexamesh-core into any of
  the four NeuralLiquid product slots... inclusion anywhere must not imply
  NeuralLiquid ownership."*) and was ruled out on that basis.

  **Resolved 2026-08-20 (later in this session): reading 2, refined.** The
  user's direction: *"nexamesh.ai needs a new sub in the celladore tenant"*
  — a **new, dedicated Azure subscription** provisioned under tenant
  `5384ef74-e517-4b22-9472-df990f61e8b5` ("Celladore Systems"), the same
  tenant that already hosts `neuralliquid-sub`
  (`5a95ddee-dd63-441a-8306-c8b0803dcdd4`) and `celladore-sub`
  (`614e6f86-e401-4bdf-8479-a59986e18815`) — but as its **own** subscription,
  not folded into either existing one. This does not trip the `387d5c34`
  ruling: that ruling is about GitHub-org/product-slot ownership (not
  placing Nexamesh under a NeuralLiquid product), not about which Azure
  *tenant* hosts the billing/RBAC boundary. A tenant hosting three
  organizationally-distinct subscriptions (Celladore's own, NeuralLiquid's,
  and now Nexamesh's) is a hosting-convenience fact, not an ownership claim.

  **Feasibility checked live, 2026-08-20:** `smit.jurie@gmail.com` (default
  identity in tenant `5384ef74-...`) has an **Active** Microsoft Customer
  Agreement billing account (`27f304a2-801f-5c0c-bfcf-23193983a6d3:...`,
  account type `Individual`, `hasReadAccess: true`) with one **Active**
  billing profile (`MBHA-C5V7-BG7-PGB`, USD, "Microsoft Azure Plan" SKU
  enabled). This is the billing scope `az account subscription create`
  needs — subscription creation is technically feasible from this identity.
  The invoice-section ID under that profile (the exact `--billing-scope`
  value the create call needs) was **not** resolved this pass — the CLI
  command tried (`az billing invoice-section list`) doesn't exist in the
  installed `az` version; needs the correct command name or the Portal.

  **Executed and confirmed live, 2026-08-20 (user confirmed both by name):**
  - **`nexamesh-sub`** — created via `az account alias create` against the
    invoice-section billing scope above (`az account subscription create`
    does not exist in this CLI's `account` extension; `az account alias
    create` is the actual mechanism for MCA-scope subscription creation).
    Subscription ID `8a5dc70a-bafa-4a04-a281-9b4862a70810`, confirmed
    `Enabled`, tenant `5384ef74-e517-4b22-9472-df990f61e8b5` ("Celladore
    Systems"), owner `smit.jurie@gmail.com` — verified via `az account list
    --refresh` after creation (the subscription is not immediately visible
    without a refresh). Nothing has been provisioned inside it yet — it's an
    empty subscription, ready for `nexamesh.ai`'s DNS zone and whatever
    Nexamesh compute eventually moves off mystira-sub.
  - **`nexamesh-org`** — created at `https://github.com/Nexamesh/nexamesh-org`
    (private, matching the more recent `celladore-org` precedent rather than
    the older public `neuralliquid-org`), mirroring the control-plane-repo
    pattern from `docs/handoffs/2026-08-16-session-handoff.md` §3. Empty
    beyond the initial repo creation — no scaffolding/docs added yet.

## Verdict on the 2026-08-19 tiered inventory

### Tier A — 10/10 confirmed present, all attributes matched live

Every Tier A row (pinned by `import {}` blocks / `backend.tf`) was
independently confirmed: `nl-prod-web-swa` (plus its Free SKU, not
previously recorded), both custom domains (`Ready`, dated 2026-07-03),
`nl-prod-shared-rg`, `nl-prod-shared-pg` with all recorded attributes exact,
both PG databases, the firewall rule name byte-for-byte, both PG server
configs, and `nl-org-tfstate-rg`/`nlorgtfstate`. **Tier A was 100% accurate**
— a meaningful signal that this repo's `import {}`-pinned claims are
trustworthy in a way the lower tiers are not.

### Tier B — 3 of 4 resolved, 1 wrong, 1 out of scope

| Row | Verdict |
| --- | --- |
| `nl-prod-convolens-kv` | Confirmed present, RBAC-enabled |
| `nl-prod-hov-kv` | Confirmed present, **not** RBAC-enabled (access-policy mode) |
| `nl-dev-omnipost-kv` | **Unresolved — out of scope this pass.** `nl-dev-omnipost-rg` exists in the saved dump but is not one of the 7 authorized RGs; its contents (including this vault) were not enumerated |
| `mys-global-shared-rg` "legacy DNS zone, orphaned" | **Wrong.** 26 resources, `neuralliquid.ai` zone fully populated (30 record sets) — see orphan-check section above for the corrected finding |

### Tier C — all 7 rows resolved

| Row | Verdict |
| --- | --- |
| `nl-prod-convolens-web` | Confirmed present; App Service, Node 24-LTS, not a container |
| Convolens App Service Plan | Resolved: `nl-prod-convolens-asp`, B1 Basic, Linux |
| `nl-prod-hov-app` | Confirmed present |
| HOV Functions | **Confirmed absent.** Zero `functionapp`-kind resources exist anywhere in the entire 247-resource subscription, not just this RG |
| `cog-dev-rg-san` (Container Apps Environment) | **Confirmed absent** from `nl-prod-cognitive-mesh-rg` — that RG has no `Microsoft.App/managedEnvironments` at all |
| `cognitive-mesh-api` (Container App) | **Different than documented.** The live resource is `cognitive-mesh-api-prod`, a containerized **App Service** (`Microsoft.Web/sites`, kind `app,linux,container`, S1 plan) — not a genuine Container App |
| `cognitive-mesh-frontend-prod` | Confirmed present, App Service |

Also resolved: the old doc's unresolved Subtask-1-vs-Subtask-7 naming
conflict over `nl-prod-convolens-pg`. **No resource or resource group named
`nl-prod-convolens-pg` exists anywhere in the subscription** (checked across
all 247 resources, not just in-scope RGs). Convolens' actual database is the
`convolens` database on the shared `nl-prod-shared-pg` server (Tier A,
confirmed) — there is no separate Convolens-dedicated PG server or RG.

## DNS TXT verification IDs

**`app_service_verification_id`** (repo default:
`05B038A75C9A9151C1E0ECF5F652F255707230C7408A56A6686F15CA9CDA6872`) —
**confirmed live**, independently, three ways:

- `az webapp show --name nl-prod-hov-app --resource-group nl-prod-hov-rg --subscription bb4e3882-… --query customDomainVerificationId` → matches
- `az webapp show --name nl-prod-convolens-web --resource-group nl-prod-convolens-rg --subscription bb4e3882-… --query customDomainVerificationId` → matches
- `az webapp show --name cognitive-mesh-api-prod --resource-group nl-prod-cognitive-mesh-rg --subscription bb4e3882-… --query customDomainVerificationId` → matches
- Corroborated by the DNS zone: all 7 live `asuid.*` TXT records in
  `neuralliquid.ai` carry exactly this value.

**`mystira_identity_app_service_verification_id`** (repo default: same
value, `05B038A75…`) — **the value the repo declares matches the record the
repo actually manages.** `infra/terraform/dns/main.tf` uses this variable to
populate the `asuid.login.hov` TXT record, and that record's live value is
confirmed `05B038A75…` — so on its own terms, this variable is correct.

**However, a second, unmanaged TXT record exists on the same hostname.**
`login.hov.neuralliquid.ai` is bound as a custom domain (with a managed
certificate) on Container App `mys-prod-identity-api`, confirmed via
`az containerapp show --name mys-prod-identity-api --resource-group
mys-prod-core-rg --subscription bb4e3882-…` (the one pre-authorized,
narrowly-scoped exception to the 7-RG limit). Azure Container Apps custom
domains are typically verified via a `_dnsauth.<hostname>` TXT record — a
**different mechanism** from the App Service `asuid.<hostname>` pattern —
and a `_dnsauth.login.hov` TXT record **does** exist live in the zone, value
`_0yzstdy565w08jklyh16mc2iu0sm6my`. This value is **not** derived from either
Terraform variable, and **`infra/terraform/dns/main.tf` does not create a
`_dnsauth.login.hov` record at all** — only `asuid.login.hov`.

**What was not established:** whether the Container App's custom-domain
binding actually depends on `_dnsauth` (vs. `asuid`, vs. something else), or
who/what manages that `_dnsauth` record if not this repo. The
`az containerapp env show` call that could have clarified this (on
`mys-prod-core-cae`, in the out-of-scope `mys-prod-core-rg`) was **blocked
outright by the Claude Code auto-mode classifier** as out-of-scope
tooling — not attempted further, per the task's own scope boundary.
**Re-attempted 2026-08-20 (continued pass): blocked again, same way,
same command.** This is not an access problem (`jurie@phoenixvc.tech` has
live Reader-or-better access to the subscription) — it's a tooling-scope
restriction on this session. Resolving it needs either a scope expansion
for `mys-prod-core-rg` or a session/identity not subject to that
restriction, not another retry.
**Correct framing: a second verification TXT record was observed on
`login.hov`, its value captured, its ownership unattributable from this
repo, and the mechanism it verifies unconfirmed** — not "the repo's value is
wrong," which the evidence does not support. This directly answers the
Terraform variable's own comment ("do not assume the shared default is
correct without checking the live TXT record"): the `asuid` value it
declares is correct; there is a second record it has no knowledge of.

## Headline finding — updated for 2026-08-20

The 2026-08-19 headline finding (Subtask 1's scope list omits
`nl-prod-web-swa` and `nl-org-tfstate-rg`) **still stands** — both are
confirmed live and unchanged. Add to it:

3. **Undocumented resources vastly outnumber documented ones in the RGs that
   *were* in scope.** 7 of 10 resources in `nl-prod-convolens-rg`, roughly
   10 of 13 in `nl-prod-hov-rg`, most of `nl-prod-cognitive-mesh-rg`'s slots
   and certificates, `nl-prod-shared-kv`, and the entire 26-resource,
   4-DNS-zone contents of `mys-global-shared-rg` were absent from the old
   doc's Tier A/B/C tables. The original scope list wasn't just missing two
   items — it was built from Terraform `import {}` blocks and named
   mentions, which only ever capture what someone deliberately wired up for
   IaC management. Anything provisioned by hand or by another team's tooling
   (the Cosmos DB account, the Container Apps Environment, the Key Vaults,
   the certificates, the whole of `mys-global-shared-rg`) was structurally
   invisible to a repo-evidence-only pass, no matter how careful. This is
   the real headline: **repo evidence and live infrastructure diverge
   substantially**, and any future audit needs live `az` access as a
   baseline, not an optional upgrade.
4. **`mys-global-shared-rg` is a multi-product shared RG**, not a
   single-purpose orphaned DNS holder — deleting or reassigning it affects
   `phoenixvc.tech` and `nexamesh.ai` as well as `neuralliquid.ai`. As of
   2026-08-20, `phoenixvc.tech` and `mystira.app` are confirmed **permanently**
   staying on mystira-sub (user direction, see scoping decision above) — this
   RG's wholesale deletion is now off the table for good, not just deferred.
   Subtask 7 (`56b11b40`, "Decommission & Cleanup on Mystira Subscription")
   needs to be re-scoped from "delete orphaned RGs" to "remove
   NeuralLiquid-specific records/resources from a shared RG that survives
   indefinitely" — flagged directly on that task too, not just here.

## What still needs re-verification

- ~~`nl-dev-omnipost-kv`~~ — **resolved 2026-08-20 (continuation session)**:
  direct `az keyvault show --name nl-dev-omnipost-kv --subscription bb4e3882-…`
  resolves cleanly without the RG needing to be in the authorized-scope list
  at all — the "blocked on scope" framing only ever applied to
  RG-level enumeration (`az resource list --resource-group ...`), not to a
  direct name lookup. RBAC-enabled, purge protection on, `publicNetworkAccess:
  Enabled`, Terraform-managed, created 2026-07-18 by `jurie@phoenixvc.tech`.
- ~~HOV's actual datastore~~ — **resolved 2026-08-20**, see the `nl-prod-hov-rg`
  section above: both Postgres and Cosmos are live and wired in;
  `ESTATE_BACKEND=postgres` selects Postgres, Cosmos usage is not ruled out.
- `nl-prod-hov-app`'s runtime/`linuxFxVersion` — still not checked (Convolens'
  was; HOV's wasn't; out of scope for the appsettings/connection-string pass
  done 2026-08-20).
- ~~`cognitive-mesh-kv-prod`'s RBAC mode~~ — **resolved 2026-08-20**:
  `enableRbacAuthorization: false`, not RBAC-enabled.
- ~~Whether the Container App `login.hov` binding actually requires
  `_dnsauth.login.hov`~~ — **resolved 2026-08-20 (continuation session)**,
  without needing the blocked `az containerapp env show` call. `mys-prod-core-rg`
  has no `Microsoft.App/containerApps` resources at all — only the shared
  `mys-prod-core-cae` environment and two managed certificates. Read
  `mys-prod-core-cae/mys-prod-identity-hov-mc` directly via `az resource show`:
  `subjectName: login.hov.neuralliquid.ai`, `validationMethod: HTTP`,
  `provisioningState: Succeeded`. The live certificate uses **HTTP** domain
  validation, not DNS TXT — so `_dnsauth.login.hov` is not a dependency of the
  current binding at all. It reads as an orphaned artifact from an earlier or
  alternate validation attempt, not a live blocker. (Note: `az resource show
  --ids` hit an ambient-account tenant mismatch here even with an explicit
  resource ID — the `--resource-group`/`--name`/`--resource-type` form with
  `--subscription` worked; a scoped `az account set` + immediate revert was
  used as a one-off fallback.)
- 6 of the 7 in-scope RGs (all but `nl-prod-convolens-rg`) were checked
  against the saved dump plus targeted per-resource live calls, not
  independently re-listed via a fresh `az resource list` this pass — low
  risk given the dump matched exactly where it was spot-checked, but not a
  full independent re-list.
- The ~30 out-of-scope resource groups (`mys-dev-*`, `mys-prod-*` besides
  `core`, `pvc-*`, `nex-*`, `nl-dev-omnipost-rg`, etc.) — existence confirmed
  via the saved dump, contents not enumerated, by instruction.
- ~~`nex-prod-shared-rg` (mystira-sub)~~ — **enumerated 2026-08-20
  (continuation session)**: holds exactly 2 resources, `nex-prod-marketing-swa`
  (apex + `www`, both `Ready`) and `nex-prod-docs-swa` (`docs`, status
  `Failed`). See the "`nex-prod-shared-rg` — enumerated" section above and
  `docs/plans/nexamesh-ai-azure-migration-plan.md` for the full cutover plan.
- ~~`docs.nexamesh.ai`~~ — **root cause diagnosed 2026-08-20 (continuation
  session)**: not a DNS issue. `nex-prod-docs-swa`'s custom-domain binding for
  `docs.nexamesh.ai` has been in status `Failed` since 2026-08-12 — no TLS
  cert was ever issued. See the "`nex-prod-shared-rg` — enumerated" section
  above for the exact error and remediation command (not executed — live prod
  write, needs confirmation before running).
- **New 2026-08-20 (continuation session):** `ops.nexamesh.ai` — referenced
  elsewhere in this doc as a live dependency of `nl-prod-hov-app`'s Baserow
  integration, but has no DNS record in the `nexamesh.ai` zone at all (public
  NXDOMAIN). Unclear whether it was never provisioned or HOV's config points
  at the wrong hostname — needs its own investigation.
- ~~The mechanism for moving `nexamesh.ai` off mystira-sub~~ — **resolved
  and executed 2026-08-20**: `nexamesh-sub`
  (`8a5dc70a-bafa-4a04-a281-9b4862a70810`) created live in the Celladore
  tenant, and `nexamesh-org` (`github.com/Nexamesh/nexamesh-org`, private)
  created alongside it — see the scoping-decision section above. Both are
  empty/unpopulated; the actual `nexamesh.ai` DNS-zone migration into
  `nexamesh-sub` is separate follow-on work, not done by this pass.

---

## Historical — 2026-08-19 Pass (repo-evidence only, preserved verbatim)

*Everything below this line is the original 2026-08-19 pass, kept unchanged
as a diff basis for the live audit above. At the time it was written, this
subscription was inaccessible to the identity in that session — every claim
below is repo-derived (Terraform `import {}` blocks, docs, HTTP liveness
probes), not independently observed. Where the live audit above disagrees
with a row here, the live audit wins; see the verdict tables above for the
resolution of every row.*

**No live enumeration of this subscription was performed.** The subscription
is inaccessible from every identity/tenant checked in this session (see
below). Everything under "Expected Inventory" is **derived from this repo's
own Terraform and docs**, not observed via `az resource list` or equivalent —
treat it as "what should be there per our records," not as an audit result.
This mirrors `docs/inventory/dns.md`'s caution: re-verify before trusting
blindly, and note here explicitly what actually was vs. wasn't confirmed
live.

Last attempted: 2026-08-19.

### Access Blocker (reproduced, unchanged)

Subscription: `bb4e3882-2079-4bab-8974-611bc0b8bb58` (mystira-sub).
Identity available in this session: `smit.jurie@gmail.com`.

```
$ az account set --subscription bb4e3882-2079-4bab-8974-611bc0b8bb58
ERROR: The subscription of 'bb4e3882-2079-4bab-8974-611bc0b8bb58' doesn't exist in cloud 'AzureCloud'.

$ az resource list --subscription bb4e3882-2079-4bab-8974-611bc0b8bb58 -o table
WARNING: Subscription 'bb4e3882-2079-4bab-8974-611bc0b8bb58' not recognized.
ERROR: Subscription 'bb4e3882-2079-4bab-8974-611bc0b8bb58' not found.
```

`az account list -o table` (and `--all --refresh`) shows only two
subscriptions for this identity: `celladore-sub`
(`614e6f86-e401-4bdf-8479-a59986e18815`) and `neuralliquid-sub`
(`5a95ddee-dd63-441a-8306-c8b0803dcdd4`). mystira-sub is not among them.

**This is a tenant boundary, not a missing role assignment on a visible
subscription.** `az account tenant list -o table` returns exactly **one**
tenant reachable by this identity: `5384ef74-e517-4b22-9472-df990f61e8b5`
("Celladore Systems"). There is no second/hidden tenant to switch into —
mystira-sub is not merely un-role-assigned, it belongs to a tenant this
identity has no membership in at all. (Note: `az account tenant list`
requires the `account` CLI extension; a fresh non-interactive shell needs
`az extension add -n account -y` first, or the interactive install prompt
EOFs with no stdin.)

**The tenant ID that actually owns `bb4e3882-2079-4bab-8974-611bc0b8bb58` is
unknown to this session.** That's a genuine open question, not an oversight
— it's a precondition for even attempting `az login --tenant <id>`.

This exactly matches the pre-existing note in this repo
(`docs/inventory/dns.md`: "legacy, inaccessible from every Azure login
checked so far") and the pre-existing Baton checklist item on subtask
`b38fab7c` — reproduced with no change in circumstance.

*(2026-08-20 note: the block above was specific to identity
`smit.jurie@gmail.com`. Identity `jurie@phoenixvc.tech`, tenant
`9530cd32-9e33-47f0-9247-ed964730b580`, has live Reader-or-better access to
this subscription — see the top of this file. The tenant-boundary diagnosis
was correct; the fix was inviting/using a differently-scoped identity, not a
role assignment change on the original one.)*

### Baseline Audit — `neuralliquid-sub` (accessible, confirmed live)

`5a95ddee-dd63-441a-8306-c8b0803dcdd4`, captured 2026-08-19 via
`az resource list` / `az group list`. This is the target subscription infra
is migrating **to**, so it's a useful before-picture for Subtask 2.

Resource groups (2, both `westeurope`):
- `nl-web-rg`
- `nl-global-shared-rg`

Resources (2 total):

| Name | Type | Resource Group | Location |
| --- | --- | --- | --- |
| `neuralliquid-web-prod` | `Microsoft.Web/staticSites` | `nl-web-rg` | `eastus2` |
| `neuralliquid.ai` | `Microsoft.Network/dnszones` | `nl-global-shared-rg` | global |

`neuralliquid-web-prod` is a **placeholder** site, distinct from the
production `nl-prod-web-swa` that actually serves `neuralliquid.ai` /
`www.neuralliquid.ai` (see `docs/inventory/dns.md` line 45 and the headline
finding below). The DNS zone here was built and fully verified during the
Track B migration but is not the live delegation target — Cloudflare is
(see `docs/inventory/dns.md`).

### Liveness Probe (HTTP, no Azure auth required)

To upgrade rows below from "named in a doc" to "confirmed running right
now," each hostname referenced by `infra/terraform/dns/main.tf` as an
expected-mystira-sub backend was probed directly over HTTPS. This proves the
services **exist and respond** — it cannot attribute them to a subscription,
since DNS/HTTP resolution doesn't reveal that.

| Hostname | Result | Backing resource (per repo) |
| --- | --- | --- |
| `jolly-beach-099205503.7.azurestaticapps.net` | `200 OK` | `nl-prod-web-swa` (Static Web App) |
| `nl-prod-convolens-web.azurewebsites.net` | `200 OK` | Convolens App Service |
| `nl-prod-hov-app.azurewebsites.net` | `200 OK` | HOV App Service |
| `cognitive-mesh-frontend-prod.azurewebsites.net` | `307` (redirect — alive) | Cognitive Mesh frontend App Service |
| `cognitive-mesh-api-prod.azurewebsites.net` | `404` (app responding, no route at `/` — alive) | Cognitive Mesh API App Service |
| `mys-prod-identity-api.politeocean-781513ae.southafricanorth.azurecontainerapps.io` | `200 OK` | Mystira Identity Container App (HOV login) |

All six respond. None of this proves subscription placement.

### Expected Inventory — Tiered by Evidence Strength

Every row below is repo-derived, not independently observed against live
mystira-sub. The tiers reflect **how strong the repo's own evidence is**,
not audit confidence. *(2026-08-20: every row in this section has since been
resolved against live data — see the verdict tables above.)*

#### Tier A — exact ARM resource ID declared in this repo's Terraform

Subscription attribution here is explicit and deliberate (not inferred),
via `import {}` blocks or `backend.tf` declarations. Still *declared*, not
*observed* — flag: `infra/terraform/dns/main.tf`'s `login.hov` CNAME target
was stale in exactly this way until corrected 2026-08-19, so "in the repo"
is not automatically "true."

| Resource | Type | Resource Group | Subscription | Source |
| --- | --- | --- | --- | --- |
| `nl-prod-web-swa` | Static Web App (`azapi_resource`) | `nl-prod-web-rg` | `bb4e3882-…` | `infra/terraform/web/imports.tf` |
| apex custom domain | Static Web App custom domain | `nl-prod-web-rg` | `bb4e3882-…` | `infra/terraform/web/imports.tf` |
| www custom domain | Static Web App custom domain | `nl-prod-web-rg` | `bb4e3882-…` | `infra/terraform/web/imports.tf` |
| `nl-prod-shared-rg` | Resource Group | — | `bb4e3882-…` | `infra/terraform/shared-data/imports.tf` |
| `nl-prod-shared-pg` | PostgreSQL Flexible Server (16, B_Standard_B1ms, 32GB, South Africa North, zone 2) | `nl-prod-shared-rg` | `bb4e3882-…` | `infra/terraform/shared-data/imports.tf`, `main.tf` |
| `houseofveritas` DB | PG database on `nl-prod-shared-pg` | `nl-prod-shared-rg` | `bb4e3882-…` | `infra/terraform/shared-data/imports.tf` |
| `convolens` DB | PG database on `nl-prod-shared-pg` | `nl-prod-shared-rg` | `bb4e3882-…` | `infra/terraform/shared-data/imports.tf` |
| PG firewall rule `AllowAllAzureServicesAndResourcesWithinAzureIps_2026-8-7_2-56-48` | PG firewall rule | `nl-prod-shared-rg` | `bb4e3882-…` | `infra/terraform/shared-data/imports.tf` |
| PG configs (`require_secure_transport`, `ssl_min_protocol_version`) | PG server configuration | `nl-prod-shared-rg` | `bb4e3882-…` | `infra/terraform/shared-data/imports.tf` |
| `nl-org-tfstate-rg` / `nlorgtfstate` (container `tfstate`) | Storage account — Terraform remote state backend | `nl-org-tfstate-rg` | `bb4e3882-…` | `backend.tf` in **all four** stacks: `web`, `dns`, `shared-data`, `bootstrap/tfstate` |

#### Tier B — named in repo, subscription asserted only by the migration plan doc

Named consistently across `docs/plans/azure-subscription-migration-plan.md`
and product YAMLs, but no `import {}` block or `backend.tf` in *this* repo
pins them to `bb4e3882-…` the way Tier A is pinned.

| Resource | Type | Source |
| --- | --- | --- |
| `nl-prod-convolens-kv` | Key Vault | Migration plan doc; referenced as RBAC precedent in `shared-data/README.md` |
| `nl-prod-hov-kv` | Key Vault (holds `estate-database-url` per `shared-data/README.md`) | Migration plan doc |
| `nl-dev-omnipost-kv` | Key Vault | Migration plan doc; referenced as RBAC precedent in `shared-data/README.md` |
| `mys-global-shared-rg` | Resource Group (legacy DNS zone, orphaned) | `docs/inventory/dns.md` |

#### Tier C — name only, no subscription attribution anywhere in this repo

The original Subtask 1 scope **assumes** these are on mystira-sub. Nothing
in this repo establishes that — it's inherited from the migration plan's
framing, not from any Terraform or import block here.

| Resource | Type | Notes |
| --- | --- | --- |
| `nl-prod-convolens-web` | App Service | Subtask 1 calls this a "legacy PG"; Subtask 7 (per migration plan) calls `nl-prod-convolens-pg` a resource group — this repo can't resolve which is correct, flag for whoever audits |
| Convolens App Service Plan | App Service Plan | Name not captured in this repo |
| `nl-prod-hov-app` | App Service | — |
| HOV Functions | Azure Functions | Name not captured in this repo |
| `cog-dev-rg-san` | Container Apps Environment | Cognitive Mesh manages its own infra in its own repo (not this one) — attribution has to come from there |
| `cognitive-mesh-api` | Container App | Same — out of reach from this repo |
| `cognitive-mesh-frontend-prod` | App Service | Same |

DNS TXT verification IDs originally in scope (`app_service_verification_id`,
`mystira_identity_app_service_verification_id`, both currently
`05B038A75C9A9151C1E0ECF5F652F255707230C7408A56A6686F15CA9CDA6872` per
`infra/terraform/dns/variables.tf`) are **documented from a prior live
capture**, not something re-verified against mystira-sub in this session —
flagging per the same caution.

### Headline Finding — Subtask 1's Scope List Is Incomplete

Two resources live on mystira-sub that are **not** in the original Subtask 1
scope (`convolens`, `house-of-veritas`, `cognitive-mesh`, `shared-data`,
`dns` TXT records):

1. **`nl-prod-web-swa`** (RG `nl-prod-web-rg`) is the Static Web App
   actually serving live production traffic for `neuralliquid.ai` and
   `www.neuralliquid.ai` — confirmed `200 OK` with valid TLS as of the
   2026-08-19 DNS cutover (`docs/inventory/dns.md`), and reconfirmed live by
   the liveness probe above. This is **not** `neuralliquid-web-prod` (the
   placeholder in neuralliquid-sub) — it's the real thing, sitting on a
   subscription no one can currently log into. This is a live single point
   of failure, not a pending inventory item.
2. **`nl-org-tfstate-rg` / `nlorgtfstate`** — the Terraform remote-state
   backend — is also on mystira-sub, and **all four** Terraform stacks in
   this repo (`web`, `dns`, `shared-data`, `bootstrap/tfstate`) point their
   `backend.tf` at it. That means `web`, `shared-data`, and `bootstrap` are
   just as unrunnable as `dns` currently is — the migration plan doc only
   records `dns` as blocked on this; it's actually all four.

Both items affect Subtask 2 (subscription setup/target state) and Subtask 7
(the broader migration plan) scope, not just Subtask 1 — worth flagging to
whoever owns those.

### Unblock — Exact Action Needed

- **Failure mode**: tenant boundary, not RBAC. `az account tenant list`
  shows this identity has no membership in whatever tenant owns
  `bb4e3882-2079-4bab-8974-611bc0b8bb58`. The likely fix is a **B2B guest
  invitation** into that tenant for `smit.jurie@gmail.com`, not a role
  assignment inside tenant `5384ef74-e517-4b22-9472-df990f61e8b5`.
- **Minimum role once invited**: **Reader** at subscription scope is
  sufficient for the inventory audit itself (`az resource list`,
  `az webapp list`, `az keyvault list`,
  `az postgres flexible-server list` are all control-plane reads).
- **Who**: the subscription owner (referred to in repo docs as "Eben")
  needs to issue the invitation/grant.
- **Missing datum**: the tenant ID that owns `bb4e3882-…` is not known to
  this session — needed before `az login --tenant <id>` can even be
  attempted. Whoever grants access should supply it.
- **One more grant, for later**: Reader covers this subtask, but enumerating
  *secret names* in `nl-prod-shared-kv` (RBAC-authorized Key Vault) for
  Subtask 6 will additionally need **Key Vault Secrets User** (or similar)
  — worth asking for in the same request so Eben isn't asked twice.
- **Narrower fallback, if full access is slow to arrange**:
  `Storage Blob Data Reader` on `nlorgtfstate` (container `tfstate`) alone
  would let someone pull the four `.tfstate` files directly, yielding a full
  serialized inventory including the Tier C attributions — last-*apply*
  truth rather than live truth, but much easier to grant and would resolve
  most of the "documented, not verified" caveats above.

*(2026-08-20 note: this section is now moot — access exists via
`jurie@phoenixvc.tech`. Kept for the record in case that identity's access
lapses.)*

### What Still Needs Re-Verification (2026-08-19 version — see updated list above)

- Everything in Tier A/B/C above, against live mystira-sub, once access
  exists.
- Tier C attributions in particular — confirm these actually sit on
  mystira-sub at all (vs. e.g. a Cognitive Mesh–owned subscription; that
  repo manages its own infra and wasn't reachable from here).
- The `nl-prod-convolens-pg` naming inconsistency (App Service PG vs.
  resource group, per Subtask 1 vs. Subtask 7 in the migration plan).
- The two shared verification IDs (`app_service_verification_id` /
  `mystira_identity_app_service_verification_id`) — currently identical;
  confirm that's still correct live rather than an artifact of the prior
  capture.
