# NeuralLiquid Static Web App adoption and deployment

## Safety properties

- The existing Static Web App and both domain resources have `prevent_destroy`.
- Import blocks adopt the live resources before Terraform manages them.
- AzAPI manages the site so the deployment token is not read into Terraform
  state. Do not replace it with `azurerm_static_web_app` without accepting that
  provider's `api_key` state behavior.
- GitHub Actions retrieves the token only after Azure OIDC login, masks it
  immediately, and passes it to the deploy action on an ephemeral runner.
- There is no long-lived GitHub deployment-token secret.

## One-time owner bootstrap

The current `nl-org-github-actions` service principal has the correct
`production` and `main` federated subjects, backend access, and DNS access, but
no access to `nl-web-rg`. Azure has no built-in role limited to Static Web
App deployment-token retrieval, so this stack defines a custom role containing
only `staticSites/read` and `staticSites/listSecrets/action`. Azure stores the
role definition at resource-group scope, but its assignment is scoped to the
single site (`neuralliquid-web-prod`), not its resource group or subscription.

The first apply creates the role and assignment, so it must be run by an Owner
or Role Based Access Control Administrator:

```powershell
az account show --query "{subscription:id,tenant:tenantId,user:user.name}"
terraform -chdir=infra/terraform/web init
terraform -chdir=infra/terraform/web plan -out=tfplan
terraform -chdir=infra/terraform/web show tfplan
terraform -chdir=infra/terraform/web apply tfplan
```

Before applying, the plan must show three imports, creation of one custom role
and one role assignment, and **no update, replacement, or deletion** of the
Static Web App or either custom domain. Stop if it does not.

After bootstrap, the site-scoped role permits the OIDC identity only to read
that site and retrieve its deployment token. It cannot change infrastructure,
manage role assignments, read the parent resource group, access DNS, or access
another Static Web App. Terraform plan/apply therefore remains an explicit
owner operation; CI performs formatting and static validation only.

## CI deployment

1. Merge the legal-site content into `main`; its deployable root is `site/`.
2. Run `Deploy Site` from `main`.
3. Enter `DEPLOY` and approve the `production` environment if a reviewer gate
   is enabled.
4. Verify `https://neuralliquid.ai`, `https://www.neuralliquid.ai`, and the
   Terms and Privacy routes.

The repository variables already required are `AZURE_CLIENT_ID`,
`AZURE_TENANT_ID`, and `AZURE_SUBSCRIPTION_ID`. No deployment-token secret is
created or maintained.
