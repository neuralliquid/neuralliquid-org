# DNS Inventory

Authoritative zone: `neuralliquid.ai`

Current Azure DNS resource group observed in existing repo notes:

- `mys-global-shared-rg`

This should be validated live before import because local Azure CLI token
acquisition was failing on 2026-07-17 with an MSAL token cache decryption error.

## Product Hosts

| Product | Host | Current target | Desired target owner | Status |
| --- | --- | --- | --- | --- |
| Convolens | `convolens.neuralliquid.ai` | `nl-prod-convolens-web.azurewebsites.net` | Convolens prod frontend App Service | Healthy |
| Omnipost | `omnipost.neuralliquid.ai` | `neuralliquid.ai` | Omnipost prod frontend App Service | Broken |
| Cognitive Mesh | `cognitive-mesh.neuralliquid.ai` | `cognitive-mesh-frontend-prod.azurewebsites.net` | Cognitive Mesh frontend App Service | Healthy |
| House of Veritas | `hov.neuralliquid.ai` | `nl-prod-hov-app.azurewebsites.net` | HOV App Service | Healthy |

## Immediate Remediation

Omnipost must not point at the apex. It needs:

1. App Service custom hostname verification TXT record.
2. CNAME to the correct Azure default hostname.
3. App Service custom hostname binding.
4. Managed certificate creation and SNI binding.
5. HTTPS health check.

## Migration Notes

- Cognitive Mesh currently manages some `neuralliquid.ai` DNS records in its own Terraform.
- HOV has known manual DNS/cert/binding drift documented in its handoff notes.
- Convolens DNS, hostname binding, and managed certificate were applied live on 2026-07-17 and now need product Terraform reconciliation.
- Omnipost has Bicep DNS/custom-domain scaffolding, but docs still reference `nexamesh.ai`.
