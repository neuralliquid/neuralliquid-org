# Azure Deployment Plan

> **Status:** Ready for Validation

Generated: 2026-07-26

## 1. Project Overview

**Goal:** Bring the existing NeuralLiquid production Static Web App, its two
custom domains, and its deployment authorization under Terraform and GitHub
OIDC without recreating the live site or persisting its deployment token.

**Path:** Add Components (existing production resource adoption)

## 2. Requirements

| Attribute | Value |
|---|---|
| Classification | Production |
| Scale | Small |
| Budget | Cost-optimized |
| Subscription | Azure subscription 1 (`bb4e3882-2079-4bab-8974-611bc0b8bb58`) |
| Location | West Europe |
| Compliance | Public legal/marketing content only; no application data |

The subscription, location, resource identity, custom domains, and SKU were
confirmed from live Azure state. The user explicitly approved Terraform and
automated CI/CD credential handling on 2026-07-26.

## 3. Components Detected

| Component | Type | Technology | Path |
|---|---|---|---|
| NeuralLiquid site | Static frontend | Raw HTML/CSS/assets | `site/` (delivered by the legal-site PR) |
| Production hosting | Existing Azure Static Web App | Free SKU | `nl-prod-web-swa` |
| Infrastructure state | Existing Azure Blob backend | Terraform | `nlorgtfstate/tfstate` |
| Automation | GitHub Actions | Azure OIDC | `.github/workflows/` |

## 4. Recipe Selection

**Selected:** Terraform

The repository already uses direct Terraform with a remote Azure backend and
OIDC-based GitHub Actions. AzAPI owns the Static Web App so its deployment key
is never read into Terraform state; AzureRM owns the custom-domain children and
least-privilege RBAC.

## 5. Architecture

**Stack:** App Service / Azure Static Web Apps

| Component | Azure Service | SKU |
|---|---|---|
| Public website | Existing Static Web App | Free |
| `neuralliquid.ai` | Existing SWA custom domain | Free allocation |
| `www.neuralliquid.ai` | Existing SWA custom domain | Free allocation |
| Terraform state | Existing Storage Account container | Existing |

The existing repository OIDC principal receives a custom role assigned only to
this Static Web App. It can read the site and retrieve its deployment token just
in time, but cannot change infrastructure. The token is masked immediately and
exists only in the ephemeral deployment runner environment.

## 6. Provisioning Limit Checklist

| Resource Type | Number to Deploy | Total After Deployment | Limit/Quota | Notes |
|---|---:|---:|---:|---|
| `Microsoft.Web/staticSites` | 0 | 1 | Existing allocation | Import only; no capacity request |
| Static Web App custom domains | 0 | 2 | 2 on Free SKU | Import only; at the current Free limit |
| Custom RBAC role | 1 | 1 | 5,000 per tenant | Narrow site-scoped operator role |
| Role assignment | 1 | 1 | 4,000 per subscription | Assigned at one Static Web App |

**Status:** All resource capacity is sufficient. No hosting resource is being
provisioned; the only additions are control-plane RBAC objects.

## 7. Execution Checklist

### Planning

- [x] Analyze workspace and live Azure state
- [x] Confirm subscription and location from the existing resource
- [x] Inventory imports and capacity
- [x] Select Terraform/AzAPI secret-safe ownership model
- [x] Record explicit user approval

### Execution

- [x] Add import-safe infrastructure stack
- [x] Extend Terraform formatting/validation CI
- [x] Add OIDC/JIT deployment workflow
- [x] Document owner bootstrap and no-replacement gate
- [x] Set status to Ready for Validation

### Validation

- [ ] Run Terraform formatting
- [ ] Initialize with backend disabled
- [ ] Validate configuration
- [ ] Confirm workflow syntax
- [ ] Run an owner-authenticated import plan and prove no replacement

### Deployment

- [ ] Merge the site-content PR first
- [ ] Run owner bootstrap apply after reviewing the import plan
- [ ] Merge this infrastructure PR
- [ ] Deploy from `main` with the production confirmation gate
- [ ] Verify both custom domains and legal routes

## 8. Files to Generate

| File | Purpose | Status |
|---|---|---|
| `.azure/plan.md` | Preparation and approval record | Complete |
| `infra/terraform/web/*` | Existing SWA imports, domains, and RBAC | Complete |
| `.github/workflows/terraform-validate.yml` | Static Terraform validation | Complete |
| `.github/workflows/deploy-site.yml` | JIT-token raw-site deployment | Complete |
| `docs/runbooks/static-site.md` | Safe adoption and deployment sequence | Complete |

## 9. Next Steps

Validate locally, publish a draft PR, and run an authenticated plan. Do not
apply if Terraform proposes an update, replacement, or deletion of the Static
Web App or either custom domain.
