# Website Legal Review Checklist

Status: **owner and legal review required before production deployment**

The draft Terms of Service and Privacy Notice deliberately avoid inventing facts that are not established in this repository. Record the approved answers here, update the pages, and have an appropriate legal reviewer confirm the final language.

## Required Decisions

1. **Contracting party and controller:** What is the full registered legal name operating NeuralLiquid and OmniPost? Is “NeuralLiquid” a company, trading name, or product brand?
2. **Contact details:** Is `omniposthq@gmail.com` approved for legal and privacy requests? Provide a durable legal/privacy address and business mailing address if required.
3. **Governing law and venue:** Which jurisdiction governs the terms, and where must disputes be brought? Are arbitration or informal-resolution steps required?
4. **User eligibility:** What minimum age applies, and may people under the age of majority use the service with consent?
5. **Privacy roles and regions:** Where is the operator established, which user regions are targeted, and which privacy regimes must the notice address?
6. **Retention and deletion:** Approve concrete schedules for OAuth connections, publishing records, security/audit logs, support communications, backups, and deleted accounts.
7. **Service providers:** Confirm the current processors/subprocessors and locations, including Azure hosting, identity providers, email, observability, databases, X, and any AI providers.
8. **Paid service terms:** Confirm whether OmniPost has paid plans. If so, approve billing, taxes, renewals, cancellation, refunds, trials, and price-change terms.
9. **Warranty and liability:** Approve the disclaimer, liability cap, excluded damages, indemnity, and mandatory consumer-law wording.
10. **Product scope:** Decide whether these pages cover only OmniPost or all NeuralLiquid products. The current drafts cover OmniPost only.
11. **International transfers and user rights:** Confirm required transfer safeguards, request-verification process, response channel, appeal process, and regulator contact language.
12. **Incident contact:** Approve the channel and procedure for security and privacy incident reports.

## Product and Engineering Verification

- Confirm OAuth tokens remain server-side, are encrypted at rest, and are never returned by application APIs.
- Confirm disconnect and credential-revocation behavior matches the notice for every supported platform.
- Confirm the connected-service list is complete and reflects production configuration.
- Confirm data export, correction, and deletion requests can be fulfilled operationally.
- Confirm the production application links to the canonical `/terms/` and `/privacy/` URLs during onboarding and in settings.
- Confirm every third-party brand and platform name is used according to its developer and branding rules.

## Approval Record

Record the reviewer, approval date, approved effective date, and a link to the final review artifact before removing the draft notices and enabling production deployment.
