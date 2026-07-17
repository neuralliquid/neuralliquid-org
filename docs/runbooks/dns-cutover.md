# DNS Cutover Runbook

Use this runbook when moving a NeuralLiquid product hostname under durable org
control.

## Preconditions

- Product App Service or Container App default hostname is known.
- Product repo has deployed the target app.
- Product owner confirms expected public hostname and health path.
- Existing DNS record and TTL are captured.

## Steps

1. Verify current DNS:

   ```powershell
   Resolve-DnsName <host>.neuralliquid.ai
   curl.exe -vkI https://<host>.neuralliquid.ai/
   ```

2. Add or verify App Service ownership TXT record:

   ```text
   asuid.<subdomain>.neuralliquid.ai
   ```

3. Bind custom hostname on the product Azure resource.

4. Create and bind an App Service managed certificate.

5. Update DNS CNAME:

   ```text
   <subdomain>.neuralliquid.ai -> <app>.azurewebsites.net
   ```

6. Verify:

   ```powershell
   Resolve-DnsName <host>.neuralliquid.ai
   curl.exe -vkI https://<host>.neuralliquid.ai/
   ```

7. Record the final target in `docs/inventory/dns.md` and `products/<product>.yaml`.

## Rollback

Restore the previous CNAME target and remove the custom hostname binding only if
the target app binding or certificate is the fault. Do not point product hosts at
the apex as a rollback target.
