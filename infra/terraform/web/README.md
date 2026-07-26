# NeuralLiquid production website

This stack adopts the existing `nl-prod-web-swa` Static Web App and its two
custom domains. It deliberately uses AzAPI for the site because the AzureRM
Static Web App resource exports the deployment API key into Terraform state.
The deployment token is never an input or output of this stack.

Read `docs/runbooks/static-site.md` before every plan or apply. Infrastructure
operations remain owner-run because the deployment identity receives only
`staticSites/read` and `staticSites/listSecrets/action`. The first apply must
also create that narrow role and assignment.
