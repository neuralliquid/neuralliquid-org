# Terraform CI and Apply

## Workflows

`Terraform Validate` runs on pull requests and pushes to `main` when Terraform
or Terraform workflow files change. It checks formatting and validates the
bootstrap, DNS and shared data stacks with backends disabled.

`Terraform DNS` is a manual workflow for the org-owned DNS stack. It can run a
remote-backed plan or apply.

`Terraform Shared Data` is the equivalent manual workflow for the shared
PostgreSQL server in `nl-prod-shared-rg`. Same shape: plan or apply, remote
backend, `production` environment.

## Current GitHub Configuration

Current mode: quick iteration. Gates are documented but not enforced while this
is a solo internal control plane.

- `production`

The `production` environment exists for deployment history and future approval
gates. Required reviewers, admin-bypass blocking, and deployment branch policies
are currently disabled.

`main` branch protection is currently disabled. Re-enable it when the repo moves
out of solo quick-iteration mode.

Add repository or environment variables:

- `AZURE_CLIENT_ID`
- `AZURE_TENANT_ID`
- `AZURE_SUBSCRIPTION_ID`

The Azure identity must use GitHub OIDC federation for this repository.

## Required Azure Permissions

For the DNS workflow identity:

- `Storage Blob Data Contributor` on `nlorgtfstate` or the `tfstate` container.
- DNS record management permissions on the `neuralliquid.ai` DNS zone in
  `mys-global-shared-rg`.

For the shared data workflow identity:

- `Storage Blob Data Contributor` on `nlorgtfstate` or the `tfstate` container.
- `Contributor` scoped to the `nl-prod-shared-rg` resource group.

Use least privilege where possible. Neither identity needs broad subscription
Contributor for routine applies.

## Apply Rules

- Run `Terraform Validate` on PRs.
- Use `Terraform DNS` and `Terraform Shared Data` in `plan` mode before `apply`.
- Apply from `main` only.
- Keep product runtime resources out of these workflows. On the shared server
  that boundary is the database: the server and the tenant databases are org
  resources; their schemas, roles and grants are not.

## Future Gates

When this control plane moves out of quick iteration, re-enable:

- `main` branch protection requiring pull requests, one approving review,
  conversation resolution, linear history, and the `Validate Terraform` status
  check.
- `production` environment required reviewers.
- `production` environment deployment branch policy for protected branches only.

## Local State Cleanup

The bootstrap and DNS states have been migrated to the Azure backend. Local
ignored `terraform.tfstate` files should not be retained after migration has been
verified.
