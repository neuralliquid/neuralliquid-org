# Session Handoff: Baserow + DocuSeal Healthy on External Postgres — DNS Wiring Started

**Date:** 2026-08-20 (continuation, same day, third session)
**Baton task worked:** `6a82ebe0` (Track C `5d5983e6`) — checklist and comment
updated; task still `todo`, not closed.
**Prior handoff:** `docs/handoffs/2026-08-20-nexamesh-migration-continuation.md`
(same date, earlier) — left both container apps created but crash-looping.
This session fixed that, then started wiring public DNS for them.
**PR:** [#15](https://github.com/neuralliquid/neuralliquid-org/pull/15)

---

## 1. What this session did

1. **Diagnosed and fixed both container apps' crash-loop.** Root cause
   (confirmed via `az containerapp logs show`): Baserow's embedded Postgres
   and DocuSeal's default SQLite are both structurally incompatible with the
   Azure Files SMB volume mount used for their data dirs (no POSIX
   `utimes()` timestamp preservation, no reliable byte-range locking over
   SMB). Fix: stood up a shared Azure Database for PostgreSQL Flexible
   Server, `nex-prod-services-db` (Burstable `Standard_B1ms`, 32GB,
   PostgreSQL 16, `northeurope`, databases `baserow` + `docuseal`), and
   wired both apps to it via env vars / Container Apps secrets. Both
   container apps are now confirmed **`Healthy`/`RunningAtMaxScale`**;
   DocuSeal additionally confirmed serving real HTTP (`302`) from its own
   hostname. (Baserow's own HTTP check from this session's sandbox timed
   out — treated as sandbox network reachability, not app health, since
   Azure's own revision status is authoritative and says Healthy.)
2. **Also fixed along the way:**
   - `baserow/baserow:1-all-in-one` no longer exists on Docker Hub — pinned
     `baserow/baserow:2.3.3`.
   - `nexamesh-sub` had never registered `Microsoft.DBforPostgreSQL` —
     first Postgres server-create attempt failed
     `MissingSubscriptionRegistration` (this is what the user's earlier
     terse "missing sub" message in this session was pointing at — not a
     missing `--subscription` flag, an actual RP-registration gap). Fixed
     with `az provider register`.
3. **Caught and remediated a self-caused incident**: an earlier Postgres
   server-create attempt (`nex-prod-services-pg`) landed in the wrong
   subscription (`celladore-sub`) because the terminal's active `az`
   subscription context had silently reverted. Caught immediately, confirmed
   zero other blast radius, cleaned up, and renamed the retry to the final
   `nex-prod-services-db` to dodge Postgres's global-server-name reuse delay
   (deleting a server doesn't free its name for tens of minutes).
4. **Baton reconnected mid-session** (was disconnected in the prior
   session/earlier this one). Logged the full saga onto task `6a82ebe0`:
   marked the old "blocked on containerapp create" checklist item done,
   added a new completed checklist item, a full narrative comment, and an
   agent handoff message.
5. **Updated and pushed the migration plan doc**
   (`docs/plans/nexamesh-ai-azure-migration-plan.md`, commit `ee37171`):
   final Postgres architecture, corrected image tag, final resource names,
   gotchas section — secrets are placeholders only, real values were never
   committed anywhere.
6. **Opened PR #15** for this branch (`docs/nexamesh-migration-continuation`).
7. **Wired public DNS for `ops.nexamesh.ai` / `sign.nexamesh.ai`**, after
   first getting corrected mid-attempt by the user: these records must
   **not** go into the source zone in `mys-global-shared-rg`
   (`mystira-sub`) — stopped before writing anything there. Confirmed
   instead the destination `nexamesh.ai` DNS zone belongs in `nexamesh-sub`
   (Celladore tenant), effectively starting Phase 1 of the migration plan
   early, scoped just to what Baserow/DocuSeal need. Found `nexamesh-sub`
   also had `Microsoft.Network` unregistered (same class of gap as the
   Postgres RP above — confusingly surfaces as `(BadRequest) The specified
   subscription ... does not exist` on any `az network` command, not an
   RP-registration-sounding error); registered it, then:
   - Created RG `nex-prod-shared-rg` (`northeurope`) and DNS zone
     `nexamesh.ai` inside it, in `nexamesh-sub`. **Note: this zone has its
     own fresh set of 4 Azure nameservers, different from the source zone's
     — record that as the Phase 3 NS-flip target when the time comes, don't
     assume they match.**
   - Added CNAME `ops` → Baserow's FQDN, TXT `asuid.ops` → the container
     apps' shared domain-verification ID, CNAME `sign` → DocuSeal's FQDN,
     TXT `asuid.sign` → same verification ID. None of this was
     classifier-blocked.
   - Attempted `az containerapp hostname add --hostname ops.nexamesh.ai`
     next — **failed** with `InvalidCustomHostNameValidation`: Azure
     validates custom domains via live public DNS, and the registrar still
     delegates `nexamesh.ai` to the OLD zone (Phase 3 not done), so the new
     zone's records are invisible to the internet. Not a bug — the expected
     chicken-and-egg consequence of standing up a new zone before cutover.
   - Asked the user how to unblock it (wait for Phase 3 vs. temporarily
     mirror these 2 records into the old zone too). **Decision: wait for
     full Phase 3 registrar cutover** — no temporary write to
     `mys-global-shared-rg`. So custom-domain binding + TLS on both
     container apps stays blocked, by decision, until Phase 3.

---

## 2. What is explicitly NOT done yet

- **Custom-domain binding + TLS for `ops.nexamesh.ai` / `sign.nexamesh.ai`
  on the container apps** — blocked by decision (see above) until Phase 3.
  Once the registrar NS is flipped to the new zone's nameservers (see
  §1 note — they differ from the source zone's), run:
  ```
  az containerapp hostname add --hostname ops.nexamesh.ai -g nex-prod-services-rg -n nex-prod-baserow-ca --subscription 8a5dc70a-bafa-4a04-a281-9b4862a70810
  az containerapp hostname bind --hostname ops.nexamesh.ai -g nex-prod-services-rg -n nex-prod-baserow-ca --environment nex-prod-services-cae --subscription 8a5dc70a-bafa-4a04-a281-9b4862a70810
  ```
  (and the equivalent pair for `sign.nexamesh.ai` / `nex-prod-docuseal-ca`).
  These `containerapp` mutations weren't tested against the classifier this
  session (the DNS-validation error hit first) — may need to be handed to
  the user directly, same pattern as `containerapp create` earlier. **Don't
  assume success** — the `docs.nexamesh.ai` SWA binding failure from an
  earlier session is a cautionary example of a binding getting stuck
  `Failed`; verify status explicitly after binding.
- **Full Phase 1 zone mirror** (apex alias, `www`, `docs`, TXT records) —
  not started; blocked on the destination SWAs (`nex-prod-marketing-swa`,
  `nex-prod-docs-swa`) not existing yet in `nexamesh-sub`.
- **Phase 3 registrar cutover** — user-only action (registrar login),
  unchanged from every prior handoff. This is now the actual blocker for
  `ops`/`sign` going live, not just a later cleanup step.
- **`nl-prod-hov-app`'s `DOCUSEAL_URL`/`DOCUSEAL_API_URL` update** to
  `sign.nexamesh.ai` — a live production app's config change; deliberately
  deferred until `sign.nexamesh.ai` is confirmed actually resolving and
  serving DocuSeal (no point pointing HOV at a hostname that doesn't work
  yet).
- **`docs.nexamesh.ai`'s existing SWA binding failure** (source side,
  `mystira-sub`) — still diagnosed-not-fixed from earlier sessions, untouched
  this session.

---

## 3. Starting checklist for next session

1. Confirm with the domain owner whether Phase 3 (registrar NS cutover) is
   ready to execute — this is now the direct blocker for `ops`/`sign` going
   live, not a distant later step. If yes, that's a bigger, separate
   decision (flips the *entire* domain's delegation, not just these two
   subdomains) — re-read the Phase 3 section of the plan doc before touching
   the registrar.
2. Once NS is flipped (or if the owner instead wants the earlier-declined
   temporary-mirror-into-the-old-zone approach reconsidered): bind custom
   domains on `nex-prod-baserow-ca` / `nex-prod-docuseal-ca`, confirm
   managed certs actually issue.
3. Update Baton `6a82ebe0` once that's confirmed working.
4. Only after that's solid: revisit whether to proceed with the rest of
   Phase 1 (SWA recreation + full zone mirror) or pause there pending the
   credential-boundary decision (Option A vs. B, still not formally
   confirmed by the domain owner despite being the working assumption).
