# Session Handoff: nexamesh.ai Migration — Checklist Executed, Cutover Plan Written

**Date:** 2026-08-20 (continuation, same day)
**Baton tasks worked:** `b38fab7c` (Subtask 1, Track B `ad65f8ed`) — closed
out; new subtask `6a82ebe0` opened under Track C `5d5983e6` for the actual
`nexamesh.ai` migration.
**Prior handoff:** `docs/handoffs/2026-08-20-nexamesh-sub-handoff.md` (same
date, earlier — PR #12, `e5a8cf1`), which left a 5-item starting checklist.
This session executed all 5.

---

## 1. What this session did

All read-only diagnosis/enumeration; no live infrastructure changes.

1. **Opened Baton subtask `6a82ebe0`** under Track C (`5d5983e6`) for the
   `nexamesh.ai` DNS + compute migration into `nexamesh-sub` — placed there
   rather than under Track B, since Track B is explicitly NeuralLiquid's own
   migration and Nexamesh work there would re-assert the ownership
   conflation task `387d5c34` rules out.
2. **Enumerated `nex-prod-shared-rg`** (mystira-sub). Exactly 2 resources,
   not 3 as previously assumed: `nex-prod-marketing-swa` (serves both the
   apex and `www`, contrary to the earlier read of the DNS zone dump) and
   `nex-prod-docs-swa`.
3. **Wrote the cutover plan**: `docs/plans/nexamesh-ai-azure-migration-plan.md`.
   Along the way, corrected the prior handoff's own instruction to "mirror
   whatever Terraform stood up `nl-global-shared-rg`" — checked
   `infra/terraform/dns` directly and found that module was never actually
   `terraform apply`'d (its backend still points at `mystira-sub`'s tfstate;
   the real zone was built by hand via `az` CLI and Terraform imports were
   retrofitted after) and its own final registrar target was superseded to
   Cloudflare the same day it was built. Neither makes it a reusable code
   template — what's reusable is the *process*, and that migration turns out
   to have hit the identical two-tenant credential split this one does,
   which independently confirms that constraint rather than being a new
   problem.
4. **Diagnosed `docs.nexamesh.ai`'s HTTPS failure**: `nex-prod-docs-swa`'s
   custom-domain binding for `docs.nexamesh.ai` has been in status `Failed`
   since 2026-08-12 — no TLS certificate was ever issued. DNS is and always
   was fine. Not fixed — it's a live production write on infra outside this
   session's day-to-day scope, so it's documented with the exact remediation
   command rather than executed.
5. **Closed both older `b38fab7c` items without hitting the classifier
   block again:**
   - `_dnsauth.login.hov` — reframed the question instead of retrying
     `az containerapp env show`. `mys-prod-core-rg` turns out to have no
     `containerApps` resources at all, only the shared environment and two
     managed certificates. Read the `login.hov` certificate directly: it
     uses **HTTP** domain validation, not DNS TXT — so `_dnsauth.login.hov`
     isn't a live dependency, just an orphaned record.
   - `nl-dev-omnipost-kv` — a direct `az keyvault show --name` resolves
     cleanly with no RG-scope requirement at all; the "blocked on scope"
     framing was only ever true for RG-level listing, not name lookups.

**Also, mid-session:** the user asked to confirm nothing in the destination
subscription would be named `mys-`-anything. Checked `neuralliquid-sub`
directly (the prior migration's destination) — confirmed clean, only `nl-`
prefixes exist there. Folded that naming rule explicitly into the new
cutover plan doc.

Full technical detail for every item above is in
`docs/inventory/azure-resources-mystira-sub.md` (updated this session) and
`docs/plans/nexamesh-ai-azure-migration-plan.md` (new).

---

## 2. What is explicitly NOT done yet

- **Nothing has moved.** `nexamesh-sub` is still empty. The plan is written;
  Phase 1 (destination scaffolding) hasn't started.
- **`docs.nexamesh.ai`'s binding is still broken** — diagnosed, not fixed.
  Remediation command is documented on Baton subtask `6a82ebe0` and in the
  inventory doc; needs a decision on whether to fix it in place on the
  source SWA now, or leave it broken until the destination SWA replaces it
  entirely (the plan recommends the latter — no reason to fix a resource
  that's about to be decommissioned).
- **`ops.nexamesh.ai`** — confirmed to not exist in DNS at all, despite
  `nl-prod-hov-app` depending on it. Not investigated further; needs someone
  to check HOV's actual Baserow config to know what it should point to.
- **Credential-boundary decision** (hand-execute via `az` CLI per side vs.
  B2B guest + dual-provider Terraform) — flagged in the plan, not resolved.
- **`nex-prod-docs-swa`'s actual deploy mechanism** — provider shows
  `SwaCli`, not GitHub. Needed before Phase 1 can recreate it correctly;
  not investigated this session.
- One older, unrelated `b38fab7c` item is still open: `nl-prod-web-swa` /
  `nlorgtfstate` scope gap (affects Subtasks 2 and 7) — untouched this
  session.

---

## 3. Starting checklist for next session

1. Resolve `nex-prod-docs-swa`'s deploy source (check for a GitHub Actions
   workflow referencing it anywhere in `Nexamesh/nexamesh-core` or elsewhere,
   or ask the user directly) — blocks Phase 1 of the migration plan.
2. Decide the credential-boundary approach (hand-execute vs. B2B guest) —
   blocks Phase 1.
3. Get user confirmation before executing the `docs.nexamesh.ai` remediation
   command on the source SWA (or decide to skip it and let the destination
   fix it structurally during the cutover instead).
4. Investigate `ops.nexamesh.ai` — check `nl-prod-hov-app`'s Baserow
   integration config to determine the intended target, independent of the
   migration.
5. Once 1–2 are resolved: execute migration Phase 1 (destination
   scaffolding) per `docs/plans/nexamesh-ai-azure-migration-plan.md`.
