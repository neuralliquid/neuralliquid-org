# DNS Inventory

Authoritative zone: `neuralliquid.ai`, hosted on **Cloudflare** (nameservers
`jack.ns.cloudflare.com` / `laylah.ns.cloudflare.com`) as of 2026-08-19.

**2026-08-19: migrated off Azure DNS entirely, not just to a new subscription.**
Originally the plan was to rebuild the zone in `neuralliquid-sub` (resource
group `nl-global-shared-rg`) and cut the registrar over to that — that zone
was built and fully verified, but the cutover target changed mid-migration:
delegating to Azure DNS again (even a subscription this org controls) was
judged to preserve the exact failure mode that caused this migration in the
first place (a subscription becoming inaccessible orphans the zone). Instead
the registrar now delegates straight to Cloudflare, populated from the same
live-verified 21-record set (see
`docs/plans/azure-subscription-migration-plan.md`, Track B / Subtask 3 for
the full execution log). Cutover confirmed end-to-end: all hostnames resolve
correctly via public resolvers, and both `neuralliquid.ai` and
`www.neuralliquid.ai` serve `200 OK` with valid TLS, confirming the Static
Web App custom-domain binding survived the DNS host change.

Both prior Azure zones are orphaned but left in place as rollback
references, not decommissioned yet (not urgent):
- `nl-global-shared-rg`, subscription `5a95ddee-dd63-441a-8306-c8b0803dcdd4`
  (neuralliquid-sub) — the zone built during this migration, ultimately not
  used as the live delegation target.
- `mys-global-shared-rg`, subscription `bb4e3882-2079-4bab-8974-611bc0b8bb58`
  (legacy, inaccessible from every Azure login checked so far) — the
  original zone this migration moved away from.

This should be re-validated live before trusting it blindly, same caution as
always: verify against Cloudflare's dashboard or a direct `nslookup` against
its nameservers rather than assuming this file stays current.

## Product Hosts

| Product | Host | Current target | Desired target owner | Status |
| --- | --- | --- | --- | --- |
| Convolens | `convolens.neuralliquid.ai` | `nl-prod-convolens-web.azurewebsites.net` | Convolens prod frontend App Service | Healthy |
| Omnipost | `omnipost.neuralliquid.ai` | `nl-dev-omnipost-web.azurewebsites.net` | Omnipost prod frontend App Service | Healthy — corrected 2026-08-19, see below |
| Cognitive Mesh | `cognitive-mesh.neuralliquid.ai` | `cognitive-mesh-frontend-prod.azurewebsites.net` | Cognitive Mesh frontend App Service | Healthy |
| Cognitive Mesh (control) | `control.cognitive-mesh.neuralliquid.ai` | `cognitive-mesh-frontend-prod.azurewebsites.net` | Cognitive Mesh frontend App Service | Healthy |
| Cognitive Mesh (API) | `api.cognitivemesh.neuralliquid.ai` | `cognitive-mesh-api-prod.azurewebsites.net` | Cognitive Mesh API App Service | Healthy |
| House of Veritas | `hov.neuralliquid.ai` | `nl-prod-hov-app.azurewebsites.net` | HOV App Service | Healthy |
| HOV login | `login.hov.neuralliquid.ai` | `mys-prod-identity-api.politeocean-781513ae.southafricanorth.azurecontainerapps.io` | Mystira Identity Container App | Healthy — `infra/terraform/dns/main.tf` had a stale dev App Service target until 2026-08-19; live was already correct |
| — (apex) | `neuralliquid.ai` | `9.163.40.246` (A) → legacy `nl-prod-web-swa` (mystira-sub) | `neuralliquid-web-prod` (`nl-web-rg` on `neuralliquid-sub`) via `docs/runbooks/web-static-app-cutover.md` | Target SWA provisioned in neuralliquid-sub; cutover scheduled via runbook |
| — (www) | `www.neuralliquid.ai` | `jolly-beach-099205503.7.azurestaticapps.net` → legacy `nl-prod-web-swa` | `neuralliquid-web-prod` (`nl-web-rg` on `neuralliquid-sub`) via `docs/runbooks/web-static-app-cutover.md` | Target SWA provisioned in neuralliquid-sub; cutover scheduled via runbook |
| — (mail) | `email.neuralliquid.ai` | `eu.mailgun.org` | Mailgun tracking CNAME | Healthy |

**Omnipost correction, 2026-08-19:** this table previously said Omnipost's
host pointed at the bare apex (`neuralliquid.ai`) and was "Broken." A live
`nslookup` this session shows it correctly CNAMEd to
`nl-dev-omnipost-web.azurewebsites.net`, matching what
`infra/terraform/dns/main.tf` has always declared. That fix must have
happened after this doc's 2026-07-17 last-verified date without the doc being
updated — the "Immediate Remediation" section below is stale and no longer
applies; left for the git-blame trail rather than deleted outright, but do
not act on it.

**Also newly captured, 2026-08-19:** no DKIM record exists at any of the
selectors Mailgun commonly uses (`smtp.`/`mailo.`/`k1._domainkey`) and no
DMARC record exists either. This is pre-existing reality, not something the
migration introduced or should silently fix — flagging it here since it's an
easy-to-miss deliverability gap (mail still sends, but is more likely to land
in spam without DKIM).

## Migration Notes

- Cognitive Mesh currently manages some `neuralliquid.ai` DNS records in its own Terraform.
- HOV had known manual DNS/cert/binding drift; the `login.hov` piece of that is now corrected in `infra/terraform/dns/main.tf` (2026-08-19) — verify against Cognitive Mesh's own Terraform separately, that wasn't audited in this pass.
- Convolens DNS, hostname binding, and managed certificate were applied live on 2026-07-17 and still need product Terraform reconciliation.
- Omnipost has Bicep DNS/custom-domain scaffolding, but docs still reference `nexamesh.ai`.

## Orphaned Azure DNS Zones & Decommissioning

### 1. `nl-global-shared-rg` (Subscription: `5a95ddee-dd63-441a-8306-c8b0803dcdd4` / `neuralliquid-sub`)
- **Status**: Orphaned / Inactive rollback reference.
- **Details**: Created on 2026-08-19 with 21 record sets across nameservers `ns1-02.azure-dns.com` through `ns4-02.azure-dns.info`. Never delegated at registrar.
- **Decommissioning / Cleanup Instructions**:
  1. Verify Cloudflare DNS (`jack.ns.cloudflare.com`, `laylah.ns.cloudflare.com`) remains fully healthy and authoritative for `neuralliquid.ai`.
  2. Backup zone records (optional):
     ```bash
     az network dns zone export --subscription 5a95ddee-dd63-441a-8306-c8b0803dcdd4 --resource-group nl-global-shared-rg --name neuralliquid.ai --file neuralliquid.ai.zone.bak
     ```
  3. Delete the Azure DNS zone:
     ```bash
     az network dns zone delete --subscription 5a95ddee-dd63-441a-8306-c8b0803dcdd4 --resource-group nl-global-shared-rg --name neuralliquid.ai --yes
     ```
  4. If `nl-global-shared-rg` contains no other resources, delete the resource group:
     ```bash
     az group delete --subscription 5a95ddee-dd63-441a-8306-c8b0803dcdd4 --name nl-global-shared-rg --yes --no-wait
     ```

### 2. `mys-global-shared-rg` (Subscription: `bb4e3882-2079-4bab-8974-611bc0b8bb58` / `mystira-sub`)
- **Status**: Inaccessible / Orphaned legacy zone.
- **Details**: Pre-migration authoritative zone (`ns*-08.azure-dns.*`). Inaccessible due to subscription credential / tenant boundary isolation. No action possible or needed from current subscription credentials.

