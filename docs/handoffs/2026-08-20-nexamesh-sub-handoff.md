# Session Handoff: nexamesh.ai Destination Resolved — nexamesh-sub & nexamesh-org Created

**Date:** 2026-08-20 (continuation, same day)
**Baton task worked:** `b38fab7c-d833-42cd-9084-5049fbc5c701` (Subtask 1, Track B `ad65f8ed`); also touched Track C `5d5983e6-bc57-46ab-8d34-4623ea9d2f71`
**PR merged:** [#12](https://github.com/neuralliquid/neuralliquid-org/pull/12) → `main` (`e5a8cf1`)
**Prior handoff:** `docs/handoffs/2026-08-20-session-handoff.md` (same date, earlier in the day — PR #11, `96d814c`)

---

## 1. What this session did

This is a direct continuation of the same-day `2026-08-20-session-handoff.md`,
which had left `nexamesh.ai`'s destination as three unresolved readings. The
user resolved it explicitly mid-session:

> "i believe nexamesh.ai needs a new sub in the celladore tenant"
> ...then, after feasibility was checked and confirmed:
> "yes on both decisions nexamesh-sub and nexamesh-org"

**Both were created live this session:**

- **`nexamesh-sub`** — Azure subscription
  `8a5dc70a-bafa-4a04-a281-9b4862a70810`, confirmed `Enabled`, tenant
  `5384ef74-e517-4b22-9472-df990f61e8b5` ("Celladore Systems") — the same
  tenant that already hosts `neuralliquid-sub`
  (`5a95ddee-dd63-441a-8306-c8b0803dcdd4`) and `celladore-sub`
  (`614e6f86-e401-4bdf-8479-a59986e18815`), but as its **own** subscription,
  not folded into either. Created via `az account alias create` against the
  Celladore tenant's MCA billing scope (billing account
  `27f304a2-801f-5c0c-bfcf-23193983a6d3:...`, profile `MBHA-C5V7-BG7-PGB`,
  invoice section `37b0347c-5d92-4f21-97fd-ee2c321f6315`) —
  **`az account subscription create` does not exist** in this CLI's
  `account` extension; `az account alias create` is the actual mechanism.
  The new subscription did not show up in `az account list` until a
  `--refresh` was forced — worth remembering if verifying this again.
  **Currently empty** — nothing provisioned inside it yet.
- **`nexamesh-org`** — `https://github.com/Nexamesh/nexamesh-org`, private.
  The `Nexamesh` GitHub org already existed (since 2026-03-25, holding only
  the public `nexamesh-core` repo); this is a genuinely new repo, mirroring
  the `neuralliquid-org` / `celladore-org` control-plane-repo pattern from
  `docs/handoffs/2026-08-16-session-handoff.md` §3. Visibility was chosen
  as **private**, matching `celladore-org` (created 2026-08-16, the more
  recent precedent) rather than the older public `neuralliquid-org` — there
  is no strict convention, this was a judgment call, flag if wrong.
  **Currently empty** beyond repo creation — no scaffolding/docs added.

**Why this doesn't conflict with the standing ownership ruling:** Baton
task `387d5c34` (referencing `6ed39c8a-86f8-4599-a7be-e506dd637e3b` in
`mystira-workspace`) rules out placing Nexamesh into any *NeuralLiquid
product slot*. A dedicated subscription inside a shared **tenant** is a
hosting/billing-boundary fact, not a product-ownership claim —
`nexamesh-sub` is its own subscription, distinct from `neuralliquid-sub`.
Recorded explicitly in both the doc and Baton comments in case this
reasoning needs to be revisited.

Full technical detail (billing account/profile/invoice-section IDs, the
`az account alias create` command actually run, verification steps) is in
`docs/inventory/azure-resources-mystira-sub.md`'s "2026-08-20 scoping
decision" section — treat this handoff as the summary, that file as the
source of record.

---

## 2. What is explicitly NOT done yet

Creating the subscription and repo only opened the destination — nothing
has moved into either yet:

- **`nexamesh.ai`'s actual DNS-zone migration** into `nexamesh-sub` — this
  is a **live registrar cutover** (the zone is genuinely authoritative,
  confirmed in the prior session pass — see
  `docs/handoffs/2026-08-20-session-handoff.md` §1, finding 2), the same
  weight of work as the `neuralliquid.ai` → Cloudflare migration. Not
  started.
- **Nexamesh compute currently on mystira-sub** — `nex-prod-shared-rg`
  (holding `nex-prod-marketing-swa`, the apex-record target, plus likely
  two more Static Web Apps behind `www`/`docs`) has still never been
  enumerated (flagged since the prior handoff). Needed before any concrete
  cutover plan — mirrors the role `nl-prod-web-rg` played for
  `neuralliquid.ai`'s migration.
- **`docs.nexamesh.ai` HTTPS/cert-binding failure** — resolves via DNS
  correctly but fails at the HTTPS layer (`curl` code `000`); likely a
  custom-domain/cert binding issue on the Static Web App. Independent bug,
  worth fixing regardless of where the domain ends up hosted — still open.
- **No Baton subtask/checklist item exists yet** specifically for "migrate
  `nexamesh.ai` DNS + compute into `nexamesh-sub`" — this session recorded
  the destination decision as comments on `b38fab7c` and `5d5983e6`, but
  did not open a dedicated tracked task for the migration itself.

---

## 3. Immediate starting checklist for next session

1. **Open a dedicated Baton subtask** for the `nexamesh.ai` DNS + compute
   migration into `nexamesh-sub` (likely under Track C `5d5983e6`, since
   it's Nexamesh-owned work, or as a new Track B-adjacent task — use
   judgment, Track B is specifically NeuralLiquid's migration).
2. **Enumerate `nex-prod-shared-rg`** (mystira-sub) — first concrete step
   before planning the cutover; also resolves the `docs.nexamesh.ai`
   binding-failure root cause.
3. **Plan the cutover** using the `neuralliquid.ai` migration as the
   template (`infra/terraform/dns-cloudflare` isn't the right template here
   since this is Azure→Azure, not Azure→Cloudflare — instead mirror
   whatever Terraform stood up `nl-global-shared-rg` in `neuralliquid-sub`,
   Track B Subtask 3 / `ab1e7ce6`, adapted for `nexamesh-sub`).
4. **Fix `docs.nexamesh.ai`'s HTTPS/cert binding** — can be done
   independently of the subscription move; a live product bug for Track C
   right now.
5. Two Subtask-1 (`b38fab7c`) checklist items are still open from before
   this decision and are unrelated to it — don't lose track of them:
   `_dnsauth.login.hov` ownership (needs `mys-prod-core-rg` scope, blocked
   by the Claude Code auto-mode classifier on `az containerapp env show` so
   far) and `nl-dev-omnipost-kv` (needs `nl-dev-omnipost-rg` added to
   authorized scope).
