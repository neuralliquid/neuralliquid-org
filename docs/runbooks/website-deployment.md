# NeuralLiquid Website Deployment

## Live Resource

The shared website is hosted by the existing Azure Static Web App:

| Setting | Value |
| --- | --- |
| Subscription | `neuralliquid-sub` (`5a95ddee-dd63-441a-8306-c8b0803dcdd4`) |
| Resource group | `nl-web-rg` |
| Resource | `neuralliquid-web-prod` |
| Azure hostname | Azure-assigned default hostname (e.g. `*.azurestaticapps.net`) |
| Custom domains | `neuralliquid.ai`, `www.neuralliquid.ai` |
| Source directory | `site/` |

The Azure resource is not repository-linked. Deployment is therefore explicit and manual; a merge to `main` does not publish the site. Infrastructure code and deployment authentication are owned by the org web-infrastructure stack, not by the content workflow.

## Before the First Deployment

1. Review `docs/legal/website-legal-review.md` and record any decisions needed for the release.
2. Confirm the terms and privacy pages show the owner-approved version and effective date and contain no draft or placeholder text.
3. In the GitHub `production` environment, configure required reviewers and restrict deployments to `main`.
4. Confirm the infrastructure-owned deployment workflow uses the approved short-lived Azure authentication path and publishes the raw `site/` directory, including `staticwebapp.config.json`.
5. Run the Static Site Validation workflow and confirm `Validate static site` passes on `main`.

## Deploy

1. Open the infrastructure-owned website deployment workflow in GitHub Actions.
2. Select `main`, provide its explicit production confirmation, and start the workflow.
3. Approve the `production` environment deployment if prompted.
4. Confirm the workflow's `Deploy production site` job succeeds.
5. Verify HTTPS responses and content for:
   - `https://neuralliquid.ai/`
   - `https://neuralliquid.ai/terms/`
   - `https://neuralliquid.ai/privacy/`
   - the corresponding `www.neuralliquid.ai` URLs
6. Complete a keyboard navigation and narrow-screen smoke test.

## Rollback

Revert the website commit on `main`, validate the revert, then manually run the infrastructure-owned deployment workflow. Record the failed and replacement workflow runs in the incident or release handoff.
