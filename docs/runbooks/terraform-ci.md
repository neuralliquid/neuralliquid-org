# Terraform CI and Apply

## Workflows

`Terraform Validate` runs on pull requests and pushes to `main` when Terraform
or Terraform workflow files change. It checks formatting and validates the
bootstrap and DNS stacks with backends disabled.

`Terraform DNS` is a manual workflow for the org-owned DNS stack. It can run a
remote-backed plan or apply.

## Required GitHub Configuration

Create a protected environment:

- `production`

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

Use least privilege where possible. The identity does not need broad
subscription Contributor for routine DNS applies.

## Apply Rules

- Run `Terraform Validate` on PRs.
- Use `Terraform DNS` in `plan` mode before `apply`.
- Apply from `main` only.
- Keep product runtime resources out of this workflow.

## Local State Cleanup

The bootstrap and DNS states have been migrated to the Azure backend. Local
ignored `terraform.tfstate` files should not be retained after migration has been
verified.
