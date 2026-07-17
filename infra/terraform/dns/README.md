# DNS Terraform

This directory will own `neuralliquid.ai` DNS records.

Initial migration should import or recreate records for:

- `convolens.neuralliquid.ai`
- `omnipost.neuralliquid.ai`
- `cognitive-mesh.neuralliquid.ai`
- `hov.neuralliquid.ai`

Start with DNS records only. Keep product-specific hostname bindings and
certificates in product repos unless cross-repo drift continues.
