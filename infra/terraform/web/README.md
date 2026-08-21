# NeuralLiquid production website

This stack manages the production `neuralliquid-web-prod` Static Web App in `neuralliquid-sub` (`5a95ddee-dd63-441a-8306-c8b0803dcdd4`, resource group `nl-web-rg`) and its two custom domains (`neuralliquid.ai` and `www.neuralliquid.ai`).

It deliberately uses AzAPI for the site because the AzureRM Static Web App resource exports the deployment API key into Terraform state. The deployment token is never an input or output of this stack.

Read `docs/runbooks/web-static-app-cutover.md` and `docs/runbooks/static-site.md` before every plan or apply. Infrastructure operations remain owner-run because the deployment identity receives only `staticSites/read` and `staticSites/listSecrets/action`. The first apply creates that narrow role and assignment.
