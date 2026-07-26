# NeuralLiquid Website Deployment

## Live Resource

The shared website is hosted by the existing Azure Static Web App:

| Setting | Value |
| --- | --- |
| Resource group | `nl-prod-web-rg` |
| Resource | `nl-prod-web-swa` |
| Azure hostname | `jolly-beach-099205503.7.azurestaticapps.net` |
| Custom domains | `neuralliquid.ai`, `www.neuralliquid.ai` |
| Source directory | `site/` |

The Azure resource is not repository-linked. Deployment is therefore explicit and manual; a merge to `main` does not publish the site.

## Before the First Deployment

1. Review `docs/legal/website-legal-review.md` and record any decisions needed for the release.
2. Confirm the terms and privacy pages show the owner-approved version and effective date and contain no draft or placeholder text.
3. In the GitHub `production` environment, configure required reviewers and restrict deployments to `main`.
4. Add `AZURE_STATIC_WEB_APPS_API_TOKEN` to the GitHub `production` environment as an Actions secret. Obtain and store it through an authorized Azure operator workflow; never print or commit it.
5. Run the Static Site workflow and confirm `Validate static site` passes on `main`.

## Deploy

1. Open **Actions → Static Site → Run workflow**.
2. Select `main`, type `DEPLOY`, and start the workflow.
3. Approve the `production` environment deployment if prompted.
4. Confirm the workflow's `Deploy production site` job succeeds.
5. Verify HTTPS responses and content for:
   - `https://neuralliquid.ai/`
   - `https://neuralliquid.ai/terms/`
   - `https://neuralliquid.ai/privacy/`
   - the corresponding `www.neuralliquid.ai` URLs
6. Complete a keyboard navigation and narrow-screen smoke test.

## Rollback

Revert the website commit on `main`, validate the revert, then manually run the Static Site workflow with `DEPLOY`. Record the failed and replacement workflow runs in the incident or release handoff.
