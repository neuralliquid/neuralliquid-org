# Session Handoff: mystira-sub Audit Continuation & DNS Scoping Decision

**Date:** 2026-08-20
**Baton task worked:** `b38fab7c-d833-42cd-9084-5049fbc5c701` (Subtask 1: Azure Resource & Subscription Inventory Audit, under Track B `ad65f8ed`)
**PR merged:** [#10](https://github.com/neuralliquid/neuralliquid-org/pull/10) → `main` (`d8fbda1`)
**Prior handoff:** `docs/handoffs/2026-08-16-session-handoff.md` (6-track portfolio roadmap — still current)

---

## 1. What this session did

Resumed `b38fab7c` with confirmed **live mystira-sub access** under identity
`jurie@phoenixvc.tech` (subscription `bb4e3882-2079-4bab-8974-611bc0b8bb58`,
tenant `9530cd32-9e33-47f0-9247-ed964730b580`) — the tenant-boundary blocker
that stalled the 2026-08-19 pass is not present under this identity. All
`az` calls this session used explicit `--subscription` flags (per the prior
pass's own warning about ambient-subscription drift silently producing
false negatives).

**Resolved 2 of the 4 previously-open checklist items, live:**

- `cognitive-mesh-kv-prod` — confirmed **not** RBAC-enabled
  (`enableRbacAuthorization: false`, access-policy mode), same pattern as
  `nl-prod-hov-kv`, unlike `nl-prod-convolens-kv` (RBAC-enabled).
- HOV's datastore ambiguity — resolved. `nl-prod-hov-app`'s app settings show
  **both** the `houseofveritas` Postgres database and the `nlprodhovcosmos`
  Cosmos Mongo account are live and wired in. `ESTATE_BACKEND=postgres`
  selects Postgres as primary; the Cosmos connection string is populated
  and not dead, but which code paths call it isn't determinable from env
  vars alone — don't delete/reprovision either datastore without checking
  the app's source.

**Still blocked/out of scope, unchanged:**

- `_dnsauth.login.hov` ownership — `az containerapp env show` on
  `mys-prod-core-cae` (`mys-prod-core-rg`) was re-attempted and **blocked
  again** by the Claude Code auto-mode classifier, same as 2026-08-19. This
  is a tooling-scope restriction, not an access problem — needs a scope
  exception or a session not subject to it, not another retry.
- `nl-dev-omnipost-kv` — `nl-dev-omnipost-rg` is still outside the
  authorized 7-RG scope; not enumerated this pass either.

**New findings surfaced (not previously known):**

1. **HOV has live runtime dependencies on Nexamesh and Mystira hostnames.**
   `nl-prod-hov-app`'s app settings reference `https://ops.nexamesh.ai`
   (Baserow ops backend), `https://docs.nexamesh.ai` (DocuSeal signing),
   and `https://identity.mystira.app` (OIDC issuer) directly. This is a
   real cross-product runtime coupling, not just a DNS-layer one — relevant
   to any future `nexamesh.ai` cutover and to why `mystira.app` staying in
   place doesn't fully decouple HOV from mystira-sub's blast radius.
2. **`nexamesh.ai`'s Azure DNS zone is genuinely live/authoritative** —
   unlike `neuralliquid.ai`'s old zone (confirmed orphaned shadow pre-
   migration), a public `nslookup -type=NS nexamesh.ai` matches this zone's
   own NS records exactly. Migrating `nexamesh.ai` off mystira-sub will be
   a **live registrar cutover**, the same category of work `neuralliquid.ai`
   went through — not a stale-zone cleanup.
3. **New scope gap: `nex-prod-shared-rg`** (mystira-sub) — holds
   `nex-prod-marketing-swa`, the actual target of `nexamesh.ai`'s apex
   record, plus likely two more Static Web Apps behind `www`/`docs`. Never
   in this audit's 7-RG authorized scope, not enumerated. Needed before any
   concrete `nexamesh.ai` migration plan (mirrors the role `nl-prod-web-rg`
   played for `neuralliquid.ai`).
4. **Track C's stated blocker was mis-described.** `docs.nexamesh.ai` is
   *not* NXDOMAIN — it resolves correctly via public DNS. The actual fault
   is at the HTTPS/connection layer (`curl` returns no response at all,
   code `000`), most likely a custom-domain/certificate binding issue on
   the Static Web App in `nex-prod-shared-rg`. Posted directly on Track C
   (`5d5983e6`) so nobody re-checks DNS records that are already fine.

Full technical detail (record dumps, exact `az`/`nslookup`/`curl` commands,
tier-by-tier verdicts) is in `docs/inventory/azure-resources-mystira-sub.md`
— treat this handoff as the summary, that file as the source of record.

---

## 2. User scoping decision, 2026-08-20 (recorded verbatim intent)

The user gave this direction mid-session; recorded here and on Baton
(`b38fab7c` comment, `56b11b40` context) rather than resolved into an
implementation choice this pass wasn't authorized to make:

- **`mystira.app` and `phoenixvc.tech` stay exactly where they are** —
  permanently out of scope for the NeuralLiquid sovereignty migration,
  staying on mystira-sub / `mys-global-shared-rg` indefinitely.
  - **Knock-on effect:** `mys-global-shared-rg` can **never** be
    wholesale-deleted (it's the one RG holding all four product DNS zones:
    `neuralliquid.ai`, `phoenixvc.tech`, `nexamesh.ai`, `mystira.app`, plus
    shared tfstate/ACR/Comms resources). Subtask 7 (`56b11b40`,
    "Decommission & Cleanup on Mystira Subscription") has been **re-scoped
    in Baton** from "delete orphaned RGs" to "remove NeuralLiquid-specific
    records/resources from a shared RG that survives indefinitely." Do not
    plan an RG deletion there — it would take out Eben's `phoenixvc.tech`
    and `mystira.app` alongside anything NeuralLiquid-owned.
  - Note: the separate `nl-global-shared-rg` zone in `neuralliquid-sub`
    (leftover from Subtask 3 / `ab1e7ce6`, never used as the live delegation
    target) is genuinely orphaned and **unaffected** by this — don't
    conflate the two RGs when eventually cleaning up.

- **`neuralliquid.ai` is confirmed already on Cloudflare** "as an
  intermediary layer" — matches the completed Subtask 3 (`ab1e7ce6`) work.
  No further action needed there.

- **`nexamesh.ai` and remaining `neuralliquid` DNS need to move to a "new
  sub"** — mechanism **not specified**, and deliberately **not decided** by
  this session. Three live readings, recorded rather than chosen:
  1. Give `nexamesh.ai` its own Cloudflare cutover, mirroring
     `neuralliquid.ai`'s exact pattern (sovereignty-agnostic, decouples
     from any Azure subscription).
  2. Move `nexamesh.ai`'s DNS into a dedicated new Azure subscription under
     Nexamesh's own control.
  3. Move `nexamesh.ai` into `neuralliquid-sub` specifically.

  **Reading 3 conflicts with a standing ruling.** Baton task `387d5c34`
  (this project) documents a prior explicit decision from task
  `6ed39c8a-86f8-4599-a7be-e506dd637e3b` (`mystira-workspace` project):
  *"Do not place Nexamesh/nexamesh-core into any of the four NeuralLiquid
  product slots... inclusion anywhere must not imply NeuralLiquid
  ownership."* Nexamesh is its own 100%-user-IP org, distinct from
  NeuralLiquid (`docs/handoffs/2026-08-16-session-handoff.md` §2). Reading 1
  is the safest default by precedent and by that ruling, **but this was not
  confirmed with the user** — get explicit sign-off before executing any
  `nexamesh.ai` DNS work, don't assume.

---

## 3. Immediate starting checklist for next session

1. **Get user confirmation on the `nexamesh.ai` destination** (Cloudflare /
   new dedicated Azure sub / neuralliquid-sub) before touching any
   `nexamesh.ai` DNS record — reading 3 needs the `387d5c34`/`6ed39c8a`
   ownership ruling explicitly revisited first if chosen.
2. Get `mys-prod-core-rg` and/or `nl-dev-omnipost-rg` added to authorized
   audit scope (or find a session/tool path not subject to the Claude Code
   classifier's block) to close the two still-open `b38fab7c` checklist
   items (`_dnsauth.login.hov` ownership, `nl-dev-omnipost-kv`).
3. Enumerate `nex-prod-shared-rg` (mystira-sub) — needed before any concrete
   `nexamesh.ai` migration plan; also would resolve the `docs.nexamesh.ai`
   cert/binding failure surfaced this session (fix that independently of
   the DNS cutover question — it's a live product bug for Track C right
   now, worth fixing regardless of where the domain ends up).
4. If reading 1 (Cloudflare) is confirmed for `nexamesh.ai`: the
   `neuralliquid.ai` cutover (`infra/terraform/dns-cloudflare`, live
   BIND-import + dashboard execution log) is the template to mirror — but
   note Baton task `46f462e1` ("Write Terraform for the live Cloudflare
   neuralliquid.ai DNS zone") is itself still `inprogress`, so even the
   *reference* pattern isn't fully IaC'd yet.
5. Track B Subtask 7 (`56b11b40`) is now correctly scoped in Baton — pick it
   up only after the live-traffic and NeuralLiquid-record-specific cleanup
   (not RG deletion) is otherwise unblocked.
