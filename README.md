# NeuralLiquid Org

Organizational control plane and product factory for NeuralLiquid.

This repo owns shared governance and cross-product platform contracts for the
NeuralLiquid product set:

- Convolens
- Omnipost
- Cognitive Mesh
- House of Veritas

Product repos continue to own application code and product-specific runtime
infrastructure. This repo owns the shared control plane: DNS, GitHub/Azure
organization policy, repo onboarding standards, product inventory, and reusable
factory patterns.

## Current Priority

Stabilize `neuralliquid.ai` DNS ownership and remove product subdomain drift.

Known live state on 2026-07-17:

| Host | Current target | Status |
| --- | --- | --- |
| `convolens.neuralliquid.ai` | `nl-prod-convolens-web.azurewebsites.net` | Healthy |
| `omnipost.neuralliquid.ai` | `neuralliquid.ai` | Broken: Azure default 404 |
| `cognitive-mesh.neuralliquid.ai` | `cognitive-mesh-frontend-prod.azurewebsites.net` | Healthy |
| `hov.neuralliquid.ai` | `nl-prod-hov-app.azurewebsites.net` | Healthy |

## Repo Boundary

This repo should own:

- `neuralliquid.ai` DNS zone records and validation TXT records.
- GitHub organization/repository policy and environment standards.
- Azure subscription/resource-group conventions, RBAC, OIDC, budgets, and shared monitoring standards.
- Product onboarding templates and launch runbooks.
- Cross-product inventory of hostnames, owners, environments, and dependencies.

Product repos should own:

- Application source code.
- Product-specific Terraform/Bicep for app resources.
- Runtime settings, databases, queues, storage, and application deployment pipelines.
- App Service/Container App hostname bindings and certificates where those resources live.

## Layout

```text
docs/
  architecture/
  inventory/
  runbooks/
infra/
  terraform/
    dns/
    github/
    azure/
products/
  <product>.yaml
```

## First Milestone

1. Import the `neuralliquid.ai` DNS record model into Terraform state.
2. Move Omnipost away from `CNAME -> neuralliquid.ai` once the target app exists.
3. Reconcile Convolens and HOV manual DNS/custom-domain drift into durable product IaC.
4. Decide whether Cognitive Mesh DNS moves here immediately or remains a documented temporary exception.
