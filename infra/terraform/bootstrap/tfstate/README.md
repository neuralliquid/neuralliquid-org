# Terraform State Bootstrap

This stack creates the Azure Storage backend used by `neuralliquid-org` Terraform
stacks.

## Resources

- Resource group: `nl-org-tfstate-rg`
- Storage account: `nlorgtfstate`
- Container: `tfstate`
- Location: `southafricanorth`

The storage account uses Standard LRS to keep control-plane state costs low. Blob
versioning and 14-day delete retention are enabled to protect state history.

## Bootstrap

This stack is the only stack that may use local state during bootstrap. After it
is applied, operational stacks must use the remote backend.

```powershell
terraform -chdir=infra/terraform/bootstrap/tfstate init
terraform -chdir=infra/terraform/bootstrap/tfstate plan
terraform -chdir=infra/terraform/bootstrap/tfstate apply
```

After the storage account exists, migrate this bootstrap stack into the remote
backend too:

```powershell
Copy-Item infra/terraform/bootstrap/tfstate/backend.tf.example infra/terraform/bootstrap/tfstate/backend.tf
terraform -chdir=infra/terraform/bootstrap/tfstate init -migrate-state
```

Do not destroy this stack. The storage account has `prevent_destroy` enabled.
