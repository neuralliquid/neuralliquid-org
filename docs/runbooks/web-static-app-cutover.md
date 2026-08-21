# NeuralLiquid Web Tier & Static Web App Cutover Runbook

**Subtask Ref:** Track B — Subtask 5 (`56298d2c-9e0c-452d-b61c-0f9276781f2a`)  
**Target:** Migrate live `neuralliquid.ai` and `www.neuralliquid.ai` web traffic from legacy `nl-prod-web-swa` (`mystira-sub`) to sovereign `neuralliquid-web-prod` (`neuralliquid-sub`).

---

## 1. Overview & Architectural Boundaries

As part of the NeuralLiquid sovereign cloud migration, the production website is transitioning from the shared Mystira Azure subscription to the dedicated NeuralLiquid Azure subscription (`neuralliquid-sub`).

### Resource Topology Comparison

| Parameter | Source (Legacy / Shared) | Target (Sovereign Target) |
| :--- | :--- | :--- |
| **Subscription** | `mystira-sub` (`bb4e3882-2079-4bab-8974-611bc0b8bb58`) | `neuralliquid-sub` (`5a95ddee-dd63-441a-8306-c8b0803dcdd4`) |
| **Tenant** | Mystira Tenant (`9530cd32-...`) | Celladore Systems Tenant (`5384ef74-e517-4b22-9472-df990f61e8b5`) |
| **Resource Group** | `nl-prod-web-rg` | `nl-web-rg` |
| **Static Web App Name** | `nl-prod-web-swa` | `neuralliquid-web-prod` |
| **Azure Region** | `westeurope` | `eastus2` |
| **SKU Tier** | Free | Free |
| **DNS Management** | Cloudflare Zone (Authoritative) | Cloudflare Zone (Authoritative) |
| **IaC State** | `infra/terraform/web` (AzAPI + AzureRM) | `infra/terraform/web` (AzAPI + AzureRM) |
| **Deploy CI Identity** | `nl-org-github-actions` Service Principal | `nl-org-github-actions` Service Principal (`369def47-8d91-4710-8c37-e521bc4a360a`) |

---

## 2. Pre-Cutover Prerequisites & Identity Alignment

### 2.1 Azure RBAC & Custom Role Setup
Azure does not offer a built-in role limited to reading Static Web App deployment tokens. Terraform (`infra/terraform/web/main.tf`) defines a scoped custom role and role assignment for GitHub Actions OIDC:
- **Role Definition:** `NeuralLiquid Static Web App Deployment Token Reader`
  - `actions`: `["Microsoft.Web/staticSites/listSecrets/action", "Microsoft.Web/staticSites/read"]`
  - `assignable_scopes`: `["/subscriptions/5a95ddee-dd63-441a-8306-c8b0803dcdd4/resourceGroups/nl-web-rg"]`
- **Role Assignment:** Assigned directly to `neuralliquid-web-prod` for Principal ID `369def47-8d91-4710-8c37-e521bc4a360a`.

### 2.2 GitHub Repository Variables Alignment
Ensure the GitHub repository / environment variables in `neuralliquid-org` are configured:
- `AZURE_SUBSCRIPTION_ID` = `5a95ddee-dd63-441a-8306-c8b0803dcdd4`
- `AZURE_TENANT_ID` = `5384ef74-e517-4b22-9472-df990f61e8b5`
- `AZURE_CLIENT_ID` = Client ID of `nl-org-github-actions` SP.

> [!NOTE]
> No static long-lived deployment secrets (e.g. `AZURE_STATIC_WEB_APPS_API_TOKEN`) are stored in GitHub Secrets. The deployment workflow fetches the token dynamically per job via OIDC.

---

## 3. Step-by-Step Cutover Execution Procedure

### Phase 1: Deploy Static Site Assets to Target SWA
Before routing live domain traffic, the target Static Web App must be seeded with the latest production website build (`site/`).

1. **Trigger Production Deployment Workflow:**
   Run GitHub Actions workflow `.github/workflows/deploy-site.yml` from branch `main` with input confirmation `DEPLOY`.
2. **Verify Staging Deployment:**
   Confirm Azure default hostname responds with 200 OK:
   ```bash
   # Retrieve defaultHostname
   az staticwebapp show \
     --name neuralliquid-web-prod \
     --resource-group nl-web-rg \
     --subscription 5a95ddee-dd63-441a-8306-c8b0803dcdd4 \
     --query defaultHostname -o tsv
   
   # Curl probe on default hostname
   curl -I https://<defaultHostname>.azurestaticapps.net
   ```

---

### Phase 2: Custom Domain Unbinding & Target Registration

> [!IMPORTANT]
> **Domain Exclusivity Requirement:**
> Azure Static Web Apps strictly rejects adding custom domains that are currently bound to another SWA resource. You must explicitly unbind `neuralliquid.ai` and `www.neuralliquid.ai` from the legacy `nl-prod-web-swa` on `mystira-sub` immediately before registering them on `neuralliquid-web-prod`.

1. **Unbind Custom Domains from Legacy SWA (mystira-sub):**
   ```powershell
   # Unbind www subdomain from legacy SWA
   az staticwebapp hostname delete `
     --name nl-prod-web-swa `
     --resource-group nl-prod-web-rg `
     --subscription bb4e3882-2079-4bab-8974-611bc0b8bb58 `
     --hostname www.neuralliquid.ai `
     --yes

   # Unbind apex domain from legacy SWA
   az staticwebapp hostname delete `
     --name nl-prod-web-swa `
     --resource-group nl-prod-web-rg `
     --subscription bb4e3882-2079-4bab-8974-611bc0b8bb58 `
     --hostname neuralliquid.ai `
     --yes
   ```

2. **Register Custom Domains on Target SWA (neuralliquid-sub):**
   ```powershell
   # Apex domain registration
   az staticwebapp hostname set `
     --name neuralliquid-web-prod `
     --resource-group nl-web-rg `
     --subscription 5a95ddee-dd63-441a-8306-c8b0803dcdd4 `
     --hostname neuralliquid.ai `
     --validation-method dns-txt-token

   # Subdomain www registration
   az staticwebapp hostname set `
     --name neuralliquid-web-prod `
     --resource-group nl-web-rg `
     --subscription 5a95ddee-dd63-441a-8306-c8b0803dcdd4 `
     --hostname www.neuralliquid.ai `
     --validation-method cname-delegation
   ```

3. **Retrieve Validation Token:**
   ```powershell
   az staticwebapp hostname show `
     --name neuralliquid-web-prod `
     --resource-group nl-web-rg `
     --subscription 5a95ddee-dd63-441a-8306-c8b0803dcdd4 `
     --hostname neuralliquid.ai `
     --query validationToken -o tsv
   ```

4. **Update Authoritative Cloudflare DNS Records:**
   In `infra/terraform/dns-cloudflare` (or Cloudflare Dashboard):
   - **Apex TXT Record (`@`):** Update the `swa_domain_verification` value with the newly retrieved `validationToken`.
   - **WWW CNAME Record (`www`):** Update `content` to point to `<neuralliquid-web-prod-defaultHostname>.azurestaticapps.net`.
   - **Apex A Record (`@`):** Ensure pointing to Azure Static Web Apps front-door IP (`9.163.40.246`).
   - Ensure all Cloudflare records remain **DNS only (grey-clouded / unproxied)**.

5. **Trigger Validation & TLS Issuance:**
   ```powershell
   az staticwebapp hostname validate `
     --name neuralliquid-web-prod `
     --resource-group nl-web-rg `
     --subscription 5a95ddee-dd63-441a-8306-c8b0803dcdd4 `
     --hostname neuralliquid.ai

   az staticwebapp hostname validate `
     --name neuralliquid-web-prod `
     --resource-group nl-web-rg `
     --subscription 5a95ddee-dd63-441a-8306-c8b0803dcdd4 `
     --hostname www.neuralliquid.ai
   ```

6. **Confirm Hostname Status:**
   ```powershell
   az staticwebapp hostname list `
     --name neuralliquid-web-prod `
     --resource-group nl-web-rg `
     --subscription 5a95ddee-dd63-441a-8306-c8b0803dcdd4 `
     -o table
   ```
   Both hostnames (`neuralliquid.ai` and `www.neuralliquid.ai`) must reach status **`Ready`**.

---

### Phase 3: Terraform State Synchronization

Once live resources and custom domains are confirmed healthy:

1. Execute Terraform Plan & Apply to adopt `neuralliquid-web-prod` and domain bindings into remote state:
   ```powershell
   terraform -chdir=infra/terraform/web init
   terraform -chdir=infra/terraform/web plan -out=tfplan
   terraform -chdir=infra/terraform/web apply tfplan
   ```
2. Verify plan shows imports and no destructive actions.

---

## 4. Post-Cutover Verification Checklist

Perform synthetic validation probes across all web entry points:

- [ ] **Apex DNS Resolution:** `nslookup neuralliquid.ai 1.1.1.1` returns `9.163.40.246`.
- [ ] **WWW DNS Resolution:** `nslookup www.neuralliquid.ai 1.1.1.1` resolves to `<target-hostname>.azurestaticapps.net`.
- [ ] **TLS Certificate Verification:**
  ```powershell
  curl.exe -vI https://neuralliquid.ai/
  curl.exe -vI https://www.neuralliquid.ai/
  ```
  Check SSL SAN includes `neuralliquid.ai` and `www.neuralliquid.ai` and issuer is Microsoft Azure RSA TLS CA.
- [ ] **HTTP 200 Route Probes:**
  - `https://neuralliquid.ai/` (Homepage)
  - `https://neuralliquid.ai/terms/` (Terms of Service)
  - `https://neuralliquid.ai/privacy/` (Privacy Policy)
  - `https://www.neuralliquid.ai/` (WWW canonical redirect / mirror)
- [ ] **Header Inspection:** Confirm security headers (`Strict-Transport-Security`, `X-Content-Type-Options: nosniff`) match `site/staticwebapp.config.json`.

---

## 5. Rollback Runbook

If SSL certificate issuance fails, validation times out, or severe routing anomalies occur:

1. **Revert Cloudflare DNS:**
   - Restore Apex TXT `swa_domain_verification` to `_t8jaqjnoysen3xbm27vutpyb5jp6vl7`.
   - Restore `www` CNAME to `jolly-beach-099205503.7.azurestaticapps.net`.
2. **Re-bind Legacy Hostnames on `nl-prod-web-swa`:**
   Ensure `nl-prod-web-swa` in `nl-prod-web-rg` (`mystira-sub`) remains in `Ready` state.
3. **Verify Legacy Traffic Restoration:**
   ```powershell
   curl.exe -I https://neuralliquid.ai/
   curl.exe -I https://www.neuralliquid.ai/
   ```
4. **Log Incident & Handoff:** Document DNS status and error logs in Baton task comments before attempting re-cutover.
