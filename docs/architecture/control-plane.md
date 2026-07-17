# NeuralLiquid Control Plane

`neuralliquid-org` is the organizational control plane and product factory for
NeuralLiquid.

## Control Plane Responsibilities

- DNS authority for `neuralliquid.ai`.
- Azure shared governance: naming, tags, budgets, RBAC, OIDC, resource-group conventions, and shared observability.
- GitHub organization policy: repository standards, branch protection, environment protection, secrets and variables policy.
- Product inventory: canonical names, owners, hostnames, environments, and health checks.
- Cross-product runbooks: DNS cutover, certificate binding, repo onboarding, incident response, and cost review.

## Factory Responsibilities

- Product launch templates.
- Terraform module patterns.
- GitHub Actions workflow standards.
- Baton task breakdown templates.
- Release gates and operational checklists.

## Product Repo Responsibilities

Product repos remain the workload plane:

- `convolens`
- `omnipost`
- `cognitive-mesh`
- `house-of-veritas`

They own application source, product-specific cloud resources, product deploy
pipelines, and runtime configuration.

## DNS Boundary

Recommended starting split:

- `neuralliquid-org` owns DNS records in `neuralliquid.ai`.
- Product repos own custom hostname bindings and certificates on their own Azure resources.
- Product repos publish expected DNS targets in `products/*.yaml` or via Terraform outputs.

This avoids Mystira-owned Terraform becoming the long-term source of truth for
NeuralLiquid domains while keeping product runtime ownership local to each app.
