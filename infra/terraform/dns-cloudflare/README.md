# Cloudflare DNS Terraform

This stack is meant to own NeuralLiquid product DNS records in the live
Cloudflare zone:

- zone: `neuralliquid.ai`
- nameservers: `jack.ns.cloudflare.com`, `laylah.ns.cloudflare.com`

It is the IaC counterpart to the manual work done on 2026-08-19
(`docs/plans/azure-subscription-migration-plan.md`, Subtask 3): the zone
itself was populated via BIND zone-file import + Cloudflare dashboard, not
Terraform, and this stack exists to close that gap — see "Follow-up: write
Terraform for the live Cloudflare zone" logged against that same subtask in
Baton (`46f462e1`).

**Status as of 2026-08-19: written, not applied, not import-verified.**
`main.tf` declares the 22 records *as documented in* `docs/inventory/dns.md`
and `infra/terraform/dns/main.tf` (the Azure counterpart, kept as a
rollback reference — see that stack's README for why Azure DNS is not the
live target) — this set has **not** been reconciled against the live
Cloudflare zone. This stack has **not** been run against the real API —
writing it did not require or use Cloudflare credentials, only the record
values already captured in this repo. `imports.tf` does not exist yet; see
"Import" below before ever running `apply` here. `scripts/generate-imports.sh`'s
22-match check *is* the reconciliation step — run it first and treat a
`# UNMATCHED` line or a match count under 22 as a signal to fix `main.tf`,
not the script. `login.hov` is the one host with a documented history of
drifting between what's declared and what's live (see the comment on
`cloudflare_dns_record.product["hov_login"]` in `main.tf`) — check it
first if the count comes up short.

**Status update, 2026-08-21: convolens target hostname dispute resolved —
live has the `-nl` suffix.** The prior note here recorded a reconciliation
pass, prompted by a separate DNS-cutover task brief, that asserted the live
`convolens` CNAME target is `nl-prod-convolens-web-nl.azurewebsites.net`
but could not verify it live (a `CLOUDFLARE_API_TOKEN` was present in the
executing agent's environment, but the agent's sandbox blocked outbound use
of it — a detected-credential guard tripped before any request left the
process). A direct `nslookup -type=CNAME convolens.neuralliquid.ai`, run
by hand outside that sandbox on 2026-08-21, returned
`nl-prod-convolens-web-nl.azurewebsites.net` — confirming the `-nl` suffix.
This file's `product_cnames.convolens.record` above, plus
`infra/terraform/dns/main.tf`, `docs/inventory/dns.md`, and
`products/convolens.yaml`, all previously declared the no-suffix form
(`nl-prod-convolens-web.azurewebsites.net`); all four have been corrected
in this pass to match the confirmed live value. Same pattern as
`login.hov`'s 2026-08-19 correction: live was correct, the declarations
were wrong. `terraform validate` against this stack's HCL (provider
`cloudflare/cloudflare` v5.23.0) passed both before and after the string
change — this was always a data question, not a syntax one.

The `CLOUDFLARE_API_TOKEN` sandbox block above is still unresolved as a
tooling gap: `scripts/generate-imports.sh` has still not been run against
the live zone (see "Import" below), so `imports.tf` still does not exist.
Note for whoever next runs it with a working token: `match_address` keys
CNAMEs on name+type only, not content, so a run against the *old*
no-suffix declaration would still have reported a "match" for `convolens`
against the live (now-corrected) record — read the raw `content` value the
script matched against directly before trusting a green "22 matched"
count, don't rely on the match itself as confirmation.

Also updated 2026-08-21: this stack is now referenced by
`.github/workflows/terraform-validate.yml` (init `-backend=false` +
`validate`, alongside bootstrap/tfstate, dns, web, and shared-data) — it no
longer sits outside CI. `.github/workflows/terraform-dns.yml` still covers
only the Azure `infra/terraform/dns` stack, and no workflow holds a
Cloudflare credential yet — `validate` doesn't need one, only `plan`/
`apply` will, and wiring that secret in remains a separate follow-up.

## Current Scope

Same 7 product hosts, 7 `asuid.*` validation records, and apex/`www`/`email`
records as `infra/terraform/dns` — see that stack's README for the per-host
list and rationale. The only structural difference is Cloudflare's flat
per-record model: the Azure MX resource's two `record` blocks and the apex
TXT resource's three `record` blocks each become independent
`cloudflare_dns_record` resources here (`apex_mx["mxa"|"mxb"]`,
`apex_txt["swa_domain_verification"|"mailgun_spf"|"openai_verification"]`),
which is why this zone has 22 individual records against the Azure zone's
21 record-sets.

Every A/CNAME record must stay **unproxied** (`proxied = false`, DNS-only /
grey cloud). The origins are Azure PaaS services relying on direct DNS
resolution for `dns-txt-token`/`cname-delegation` domain validation and
Azure-managed TLS — proxying breaks that validation silently. This was a
deliberate decision made during the 2026-08-19 cutover (declined
Cloudflare's onboarding suggestion to proxy for CDN/DDoS benefits). Do not
flip any of these to `proxied = true` without re-validating domain
ownership and cert renewal for that host first.

Not in scope here yet: DKIM/DMARC records for Mailgun (Baton `7cc56dab`,
still open — no record values exist to add).

## Backend

Same remote-state storage account the rest of `neuralliquid-org` Terraform
targets (`nlorgtfstatesa`, see `infra/terraform/bootstrap/tfstate`), under a
stack-specific key (`dns-cloudflare/terraform.tfstate`) so it doesn't
collide with `infra/terraform/dns`'s state. That storage account is provisioned
in `neuralliquid-sub` (`5a95ddee-dd63-441a-8306-c8b0803dcdd4`) via Baton Subtask 2 (`15ef97d6`). Before the bootstrap stack is applied:

```powershell
terraform -chdir=infra/terraform/dns-cloudflare init -backend=false
terraform -chdir=infra/terraform/dns-cloudflare validate
```

is as far as this stack can go. Once the bootstrap stack is applied:

```powershell
terraform -chdir=infra/terraform/dns-cloudflare init
terraform -chdir=infra/terraform/dns-cloudflare plan
```

## Credentials

`var.cloudflare_api_token` must be a scoped token (Zone:DNS:Edit,
restricted to just the `neuralliquid.ai` zone) — the same scoping used when
the token was generated during the 2026-08-19 cutover. Supply it via
`TF_VAR_cloudflare_api_token` or a CI secret; never commit a real value or
put it in `terraform.tfvars`.

## Import

**Do not run `terraform apply` on this stack before importing.** All 22
records already exist live — an apply without importing first would try to
create duplicates of every one of them and fail (or, worse, partially
succeed and leave the zone in a mixed manual/Terraform state).

Cloudflare record IDs are opaque API-assigned hashes, unlike Azure's
deterministic resource-ID paths — there is no way to hand-write correct
`import` blocks the way `infra/terraform/dns/imports.tf` does. Generate
`imports.tf` instead, from whoever/whatever next has the scoped API token:

```bash
CLOUDFLARE_API_TOKEN=... ./scripts/generate-imports.sh > imports.tf
```

This queries the live zone, matches each record to its `main.tf` resource
address by name/type/content, and emits one `import` block per record. It
warns on stderr if it matches anything other than exactly 22 records —
investigate before proceeding if so, don't apply against a partial match.
See the script's header comment for details.

With `imports.tf` generated and a working backend, `terraform apply` will
import all 22 records before managing them (Terraform 1.5+ `import` block
behavior), same pattern as `infra/terraform/dns`.
