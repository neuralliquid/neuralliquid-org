# 2026-08-19: all IDs below updated to the new zone built during the org-wide
# DNS migration (docs/plans/azure-subscription-migration-plan.md, Track B) —
# subscription 5a95ddee-dd63-441a-8306-c8b0803dcdd4 (neuralliquid-sub),
# resource group nl-global-shared-rg. Previously these pointed at the legacy
# zone (bb4e3882-2079-4bab-8974-611bc0b8bb58 / mys-global-shared-rg), which
# is orphaned but left in place as a rollback path — not deleted.
#
# This module's own backend.tf still targets that legacy subscription for
# remote state, so none of this can actually be applied yet (blocked on the
# Track B state-backend bootstrap). Records were created directly via `az`
# CLI; these import blocks let a future `terraform apply` adopt them instead
# of erroring on duplicates once the backend is unblocked.

import {
  to = azurerm_dns_cname_record.product["convolens"]
  id = "/subscriptions/5a95ddee-dd63-441a-8306-c8b0803dcdd4/resourceGroups/nl-global-shared-rg/providers/Microsoft.Network/dnsZones/neuralliquid.ai/CNAME/convolens"
}

import {
  to = azurerm_dns_cname_record.product["omnipost"]
  id = "/subscriptions/5a95ddee-dd63-441a-8306-c8b0803dcdd4/resourceGroups/nl-global-shared-rg/providers/Microsoft.Network/dnsZones/neuralliquid.ai/CNAME/omnipost"
}

import {
  to = azurerm_dns_cname_record.product["cognitive_mesh"]
  id = "/subscriptions/5a95ddee-dd63-441a-8306-c8b0803dcdd4/resourceGroups/nl-global-shared-rg/providers/Microsoft.Network/dnsZones/neuralliquid.ai/CNAME/cognitive-mesh"
}

import {
  to = azurerm_dns_cname_record.product["cognitive_mesh_control"]
  id = "/subscriptions/5a95ddee-dd63-441a-8306-c8b0803dcdd4/resourceGroups/nl-global-shared-rg/providers/Microsoft.Network/dnsZones/neuralliquid.ai/CNAME/control.cognitive-mesh"
}

import {
  to = azurerm_dns_cname_record.product["cognitive_mesh_api"]
  id = "/subscriptions/5a95ddee-dd63-441a-8306-c8b0803dcdd4/resourceGroups/nl-global-shared-rg/providers/Microsoft.Network/dnsZones/neuralliquid.ai/CNAME/api.cognitivemesh"
}

import {
  to = azurerm_dns_cname_record.product["hov"]
  id = "/subscriptions/5a95ddee-dd63-441a-8306-c8b0803dcdd4/resourceGroups/nl-global-shared-rg/providers/Microsoft.Network/dnsZones/neuralliquid.ai/CNAME/hov"
}

# 2026-08-19: previously had no import block at all (a real, standing gap —
# not new). Added now that the record exists in the new zone with the
# corrected live value.
import {
  to = azurerm_dns_cname_record.product["hov_login"]
  id = "/subscriptions/5a95ddee-dd63-441a-8306-c8b0803dcdd4/resourceGroups/nl-global-shared-rg/providers/Microsoft.Network/dnsZones/neuralliquid.ai/CNAME/login.hov"
}

import {
  to = azurerm_dns_txt_record.app_service_validation["convolens"]
  id = "/subscriptions/5a95ddee-dd63-441a-8306-c8b0803dcdd4/resourceGroups/nl-global-shared-rg/providers/Microsoft.Network/dnsZones/neuralliquid.ai/TXT/asuid.convolens"
}

import {
  to = azurerm_dns_txt_record.app_service_validation["omnipost"]
  id = "/subscriptions/5a95ddee-dd63-441a-8306-c8b0803dcdd4/resourceGroups/nl-global-shared-rg/providers/Microsoft.Network/dnsZones/neuralliquid.ai/TXT/asuid.omnipost"
}

import {
  to = azurerm_dns_txt_record.app_service_validation["cognitive_mesh"]
  id = "/subscriptions/5a95ddee-dd63-441a-8306-c8b0803dcdd4/resourceGroups/nl-global-shared-rg/providers/Microsoft.Network/dnsZones/neuralliquid.ai/TXT/asuid.cognitive-mesh"
}

import {
  to = azurerm_dns_txt_record.app_service_validation["cognitive_mesh_control"]
  id = "/subscriptions/5a95ddee-dd63-441a-8306-c8b0803dcdd4/resourceGroups/nl-global-shared-rg/providers/Microsoft.Network/dnsZones/neuralliquid.ai/TXT/asuid.control.cognitive-mesh"
}

import {
  to = azurerm_dns_txt_record.app_service_validation["cognitive_mesh_api"]
  id = "/subscriptions/5a95ddee-dd63-441a-8306-c8b0803dcdd4/resourceGroups/nl-global-shared-rg/providers/Microsoft.Network/dnsZones/neuralliquid.ai/TXT/asuid.api.cognitivemesh"
}

import {
  to = azurerm_dns_txt_record.app_service_validation["hov"]
  id = "/subscriptions/5a95ddee-dd63-441a-8306-c8b0803dcdd4/resourceGroups/nl-global-shared-rg/providers/Microsoft.Network/dnsZones/neuralliquid.ai/TXT/asuid.hov"
}

# 2026-08-19: previously had no import block at all, same as the CNAME above.
import {
  to = azurerm_dns_txt_record.app_service_validation["hov_login"]
  id = "/subscriptions/5a95ddee-dd63-441a-8306-c8b0803dcdd4/resourceGroups/nl-global-shared-rg/providers/Microsoft.Network/dnsZones/neuralliquid.ai/TXT/asuid.login.hov"
}

# 2026-08-19: apex/www/email records — newly IaC-owned as of this migration,
# see the comment above azurerm_dns_a_record.apex in main.tf.
import {
  to = azurerm_dns_a_record.apex
  id = "/subscriptions/5a95ddee-dd63-441a-8306-c8b0803dcdd4/resourceGroups/nl-global-shared-rg/providers/Microsoft.Network/dnsZones/neuralliquid.ai/A/@"
}

import {
  to = azurerm_dns_mx_record.apex
  id = "/subscriptions/5a95ddee-dd63-441a-8306-c8b0803dcdd4/resourceGroups/nl-global-shared-rg/providers/Microsoft.Network/dnsZones/neuralliquid.ai/MX/@"
}

import {
  to = azurerm_dns_txt_record.apex
  id = "/subscriptions/5a95ddee-dd63-441a-8306-c8b0803dcdd4/resourceGroups/nl-global-shared-rg/providers/Microsoft.Network/dnsZones/neuralliquid.ai/TXT/@"
}

import {
  to = azurerm_dns_cname_record.www
  id = "/subscriptions/5a95ddee-dd63-441a-8306-c8b0803dcdd4/resourceGroups/nl-global-shared-rg/providers/Microsoft.Network/dnsZones/neuralliquid.ai/CNAME/www"
}

import {
  to = azurerm_dns_cname_record.email
  id = "/subscriptions/5a95ddee-dd63-441a-8306-c8b0803dcdd4/resourceGroups/nl-global-shared-rg/providers/Microsoft.Network/dnsZones/neuralliquid.ai/CNAME/email"
}
