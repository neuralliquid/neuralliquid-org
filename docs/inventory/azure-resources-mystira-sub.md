# Azure Resource Inventory — Mystira Subscription (`bb4e3882…`)

**No live enumeration of this subscription was performed.** The subscription
is inaccessible from every identity/tenant checked in this session (see
below). Everything under "Expected Inventory" is **derived from this repo's
own Terraform and docs**, not observed via `az resource list` or equivalent —
treat it as "what should be there per our records," not as an audit result.
This mirrors `docs/inventory/dns.md`'s caution: re-verify before trusting
blindly, and note here explicitly what actually was vs. wasn't confirmed
live.

Last attempted: 2026-08-19.

## Access Blocker (reproduced, unchanged)

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

## Baseline Audit — `neuralliquid-sub` (accessible, confirmed live)

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

## Liveness Probe (HTTP, no Azure auth required)

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

## Expected Inventory — Tiered by Evidence Strength

Every row below is repo-derived, not independently observed against live
mystira-sub. The tiers reflect **how strong the repo's own evidence is**,
not audit confidence.

### Tier A — exact ARM resource ID declared in this repo's Terraform

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

### Tier B — named in repo, subscription asserted only by the migration plan doc

Named consistently across `docs/plans/azure-subscription-migration-plan.md`
and product YAMLs, but no `import {}` block or `backend.tf` in *this* repo
pins them to `bb4e3882-…` the way Tier A is pinned.

| Resource | Type | Source |
| --- | --- | --- |
| `nl-prod-convolens-kv` | Key Vault | Migration plan doc; referenced as RBAC precedent in `shared-data/README.md` |
| `nl-prod-hov-kv` | Key Vault (holds `estate-database-url` per `shared-data/README.md`) | Migration plan doc |
| `nl-dev-omnipost-kv` | Key Vault | Migration plan doc; referenced as RBAC precedent in `shared-data/README.md` |
| `mys-global-shared-rg` | Resource Group (legacy DNS zone, orphaned) | `docs/inventory/dns.md` |

### Tier C — name only, no subscription attribution anywhere in this repo

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

## Headline Finding — Subtask 1's Scope List Is Incomplete

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

## Unblock — Exact Action Needed

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

## What Still Needs Re-Verification

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
