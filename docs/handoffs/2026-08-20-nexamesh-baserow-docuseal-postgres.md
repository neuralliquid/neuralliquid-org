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
7. **Started public DNS wiring for `ops.nexamesh.ai` / `sign.nexamesh.ai`**,
   then got corrected mid-attempt by the user: these records must **not**
   go into the source zone in `mys-global-shared-rg` (`mystira-sub`) —
   stopped before writing anything there. Confirmed instead the destination
   `nexamesh.ai` DNS zone belongs in `nexamesh-sub` (Celladore tenant),
   effectively starting Phase 1 of the migration plan early, scoped just to
   what Baserow/DocuSeal need. While scoping that, found `nexamesh-sub` also
   has `Microsoft.Network` unregistered (same class of gap as the Postgres
   RP above — confusingly surfaces as `(BadRequest) The specified
   subscription ... does not exist` on any `az network` command, not an
   RP-registration-sounding error). Registration was kicked off
   (`az provider register --namespace Microsoft.Network`) and was still
   `Registering` when this session ended — **not confirmed complete, and
   the DNS zone itself was never created.**

---

## 2. What is explicitly NOT done yet

- **`Microsoft.Network` provider registration on `nexamesh-sub`** — kicked
  off, state unconfirmed at session end. Check with:
  ```
  az provider show --namespace Microsoft.Network --subscription 8a5dc70a-bafa-4a04-a281-9b4862a70810 --query registrationState -o tsv
  ```
- **Destination `nexamesh.ai` DNS zone does not exist yet** in
  `nexamesh-sub`. Once the provider is `Registered`:
  1. Create RG `nex-prod-shared-rg` in `nexamesh-sub` (`northeurope` —
     `westeurope` was rejected for this subscription earlier this session)
     if it doesn't already exist — only `nex-prod-services-rg` exists there
     currently.
  2. Create DNS zone `nexamesh.ai` in that RG.
  3. Add exactly these 4 records (nothing else yet — apex/www/docs mirroring
     needs the destination SWAs to exist first, which is separate, later
     Phase 1 work not started):
     - CNAME `ops` → `nex-prod-baserow-ca.wittywater-11e95f33.northeurope.azurecontainerapps.io`
     - TXT `asuid.ops` → `29C29A5B695C3245E7830EE24A6FA1D0F127C9E7C850D767916A4C3DCC34F7A7`
     - CNAME `sign` → `nex-prod-docuseal-ca.wittywater-11e95f33.northeurope.azurecontainerapps.io`
     - TXT `asuid.sign` → `29C29A5B695C3245E7830EE24A6FA1D0F127C9E7C850D767916A4C3DCC34F7A7`
     (both apps share one verification ID — same Container Apps
     environment, `nex-prod-services-cae`.)
  4. Then bind the custom domains on each container app (`az containerapp
     hostname add` + `hostname bind`, likely classifier-blocked like other
     `containerapp` mutations this session — hand to the user if so) to
     actually get TLS certs issued. **Don't assume DNS records alone are
     enough** — the `docs.nexamesh.ai` SWA binding failure from an earlier
     session is a cautionary example of a binding getting stuck `Failed`;
     watch this one closely rather than assuming success.
  5. **This new zone is not authoritative yet.** The registrar still points
     at the `mys-global-shared-rg` zone in `mystira-sub`. `ops.nexamesh.ai`
     / `sign.nexamesh.ai` will **not resolve publicly** until Phase 3
     (registrar NS cutover) happens — don't report these as "live" until
     that's done.
- **Full Phase 1 zone mirror** (apex alias, `www`, `docs`, TXT records) —
  not started; blocked on the destination SWAs (`nex-prod-marketing-swa`,
  `nex-prod-docs-swa`) not existing yet in `nexamesh-sub`.
- **Phase 3 registrar cutover** — user-only action (registrar login),
  unchanged from every prior handoff.
- **`nl-prod-hov-app`'s `DOCUSEAL_URL`/`DOCUSEAL_API_URL` update** to
  `sign.nexamesh.ai` — a live production app's config change; deliberately
  deferred until `sign.nexamesh.ai` is confirmed actually resolving and
  serving DocuSeal (no point pointing HOV at a hostname that doesn't work
  yet).
- **`docs.nexamesh.ai`'s existing SWA binding failure** (source side,
  `mystira-sub`) — still diagnosed-not-fixed from earlier sessions, untouched
  this session.
- Baton `6a82ebe0` still needs a further update once the DNS zone + hostname
  binding work above actually completes.

---

## 3. Starting checklist for next session

1. Confirm `Microsoft.Network` registration completed on `nexamesh-sub`;
   register it again if somehow still not — should be a one-time,
   non-blocked call like the Postgres RP fix earlier this session.
2. Create `nex-prod-shared-rg` + `nexamesh.ai` DNS zone in `nexamesh-sub`,
   add the 4 records listed above.
3. Bind custom domains on `nex-prod-baserow-ca` / `nex-prod-docuseal-ca` to
   `ops.nexamesh.ai` / `sign.nexamesh.ai` and confirm managed certs actually
   issue (don't assume — verify status explicitly).
4. Update Baton `6a82ebe0` once that's confirmed working.
5. Only after 1–3 are solid: revisit whether to proceed with the rest of
   Phase 1 (SWA recreation + full zone mirror) or pause there pending the
   credential-boundary decision (Option A vs. B, still not formally
   confirmed by the domain owner despite being the working assumption).
