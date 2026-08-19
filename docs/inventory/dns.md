# DNS Inventory

Authoritative zone: `neuralliquid.ai`

**2026-08-19: zone migrated.** A fresh copy of the zone was built in
`neuralliquid-sub` (resource group `nl-global-shared-rg`, subscription
`5a95ddee-dd63-441a-8306-c8b0803dcdd4`) as part of the org-wide DNS migration
(`docs/plans/azure-subscription-migration-plan.md`, Track B). It was
populated by querying every live record directly (not from this file or from
Terraform, both of which had drifted from reality — see the Omnipost and
`login.hov` corrections below) and validated by querying the new zone's own
nameservers. It is **not yet live** — the registrar (Dynadot) still delegates
to the old zone's nameservers, and that flip requires the domain owner's
registrar login, so it isn't something this repo/session can execute. Until
that NS cutover happens, the record below is still true and still
authoritative:

- `mys-global-shared-rg`, subscription `bb4e3882-2079-4bab-8974-611bc0b8bb58`
  (legacy, inaccessible from every Azure login checked so far)

That old zone is left in place, orphaned but not deleted, as the rollback
path if the cutover needs to be reversed — this repo/subscription never had
delete access to it anyway.

This should be re-validated live before trusting it, same caution as before:
local Azure CLI token acquisition to the *old* subscription was failing on
2026-07-17 with an MSAL token cache decryption error, and remains inaccessible
as of 2026-08-19.

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
| — (apex) | `neuralliquid.ai` | `9.163.40.246` (A) → `nl-prod-web-swa` | `infra/terraform/web` Static Web App | Healthy — a placeholder site distinct from `neuralliquid-web-prod`; see that repo's PRD open decision on apex-vs-subdomain |
| — (www) | `www.neuralliquid.ai` | `jolly-beach-099205503.7.azurestaticapps.net` → `nl-prod-web-swa` | same as apex | Healthy |
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
