---
name: setup_workflow
description: Generate deployment workflow for any repo. Detects repo type (standalone vs monorepo), collects configuration, generates GitHub Actions workflow and deployment scripts.
---

The /setup_workflow command generates a complete GitHub Actions deployment workflow for the current repository.

## Phase 1: Detect Repo Type

Inspect the repository to determine its structure before asking the user any questions.

1. Read `package.json` in the current directory. If it has a `workspaces` field, the repo is a monorepo. Otherwise it is standalone.
2. Glob for `.github/workflows/deploy*.yml`. If any match:
   - Warn the user: "A deployment workflow already exists at `<path>`. Overwrite it or create a new file alongside it?"
   - Use AskUserQuestion to ask: "overwrite" or "create alongside"
   - If "create alongside", the generated file will be named to avoid the conflict.
3. Record the repo type and the existing-workflow decision before proceeding.

## Phase 2: Collect Configuration

Use AskUserQuestion to collect all required values. Ask all questions in a single call where possible. Do not guess values; ask explicitly.

### Questions for all repos

1. App name — suggest the directory name of the current repo as the default. Example: "What is the app name? (default: my-app)"
2. Environments to deploy — multi-select: prod, uat, dev. Default: all three. Example: "Which environments should the workflow deploy to? (prod, uat, dev — default: all)"
3. Container port — the port the app listens on inside the container. Default: 3000.
4. Health check path — the HTTP path used for health checks. Default: /health.
5. GitHub owner for GHCR — the GitHub organization or user that owns the container registry. Default: qwickapps.
6. For each selected environment, ask for its domain:
   - If prod selected: "Production domain (e.g., myapp.example.com)"
   - If uat selected: "UAT domain (e.g., uat.myapp.example.com)"
   - If dev selected: "Dev domain (e.g., dev.myapp.example.com)"

### Additional questions for monorepo

If the repo is a monorepo, also ask:

7. Product name — the identifier used in workflow filenames and CapRover app names. Example: "faabzi"
8. Client path — the path to the product directory relative to repo root. Example: "clients/faabzi"

Store all collected values before proceeding to Phase 3.

## Phase 3: Generate Workflow

1. Select the template based on repo type:
   - Standalone: `${CLAUDE_PLUGIN_ROOT}/templates/deploy-standalone.yml`
   - Monorepo: `${CLAUDE_PLUGIN_ROOT}/templates/deploy-monorepo-product.yml`

2. Read the template file.

3. Replace all `__PLACEHOLDER__` tokens with the collected values. The following tokens are used in the templates:

   | Token | Value |
   |-------|-------|
   | `__APP_NAME__` | App name collected in Phase 2 |
   | `__CONTAINER_PORT__` | Container port |
   | `__HEALTH_PATH__` | Health check path |
   | `__GITHUB_OWNER__` | GitHub owner for GHCR |
   | `__PROD_DOMAIN__` | Production domain (if prod selected) |
   | `__UAT_DOMAIN__` | UAT domain (if uat selected) |
   | `__DEV_DOMAIN__` | Dev domain (monorepo only; standalone derives dev URL from SHA) |
   | `__PRODUCT_NAME__` | Product name (monorepo only) |
   | `__CLIENT_PATH__` | Client path (monorepo only) |

   For environments not selected, remove the corresponding job blocks from the generated workflow rather than leaving placeholder tokens.

4. Determine the output path:
   - Standalone: `.github/workflows/deploy.yml`
   - Monorepo: `.github/workflows/deploy-<product>.yml`
   - If the user chose "create alongside" in Phase 1, append `-new` before `.yml`.

5. Create the `.github/workflows/` directory if it does not exist.

6. Write the generated workflow to the output path.

## Phase 4: Copy Scripts

1. List all files in `${CLAUDE_PLUGIN_ROOT}/scripts/`.
2. Create `.github/scripts/` in the target repo if it does not exist.
3. For each script file, read it and write it to `.github/scripts/<filename>`.
4. Make each script executable: run `chmod +x .github/scripts/<filename>` for each file.

Do not overwrite scripts that already exist in `.github/scripts/` unless they are identical in name to plugin scripts. If a conflict exists, warn the user and skip that file.

## Phase 5: Generate .env.deploy.example

Create `.env.deploy.example` in the repo root with the following content:

```
# Required GitHub Secrets for deployment
# Add these in Settings > Secrets and variables > Actions

# CapRover (OCI_MAIN - prod/uat)
CAPROVER_URL=https://captain.app.qwickforge.com
CAPROVER_PASSWORD=

# CapRover (OCI_DEV - dev)
OCI_DEV_CAPROVER_URL=https://captain.dev.qwickforge.com
OCI_DEV_CAPROVER_PASSWORD=

# QwickWay Gateway (route)
ROUTE_CAPROVER_URL=https://captain.route.qwickforge.com
ROUTE_CAPROVER_PASSWORD=

# GHCR pull token (for CapRover to pull images)
GHCR_PULL_TOKEN=
```

If only a subset of environments was selected in Phase 2, include only the secrets relevant to those environments:
- prod and uat require `CAPROVER_URL` and `CAPROVER_PASSWORD`
- dev requires `OCI_DEV_CAPROVER_URL` and `OCI_DEV_CAPROVER_PASSWORD`
- Any environment with a QwickWay gateway requires `ROUTE_CAPROVER_URL` and `ROUTE_CAPROVER_PASSWORD`
- All environments require `GHCR_PULL_TOKEN`

## Phase 6: Summary

Print a structured summary of what was generated. Use plain text, no emojis.

```
Setup complete.

Files created:
  .github/workflows/<workflow-file>.yml
  .github/scripts/configure-caprover-app.sh
  .github/scripts/deploy-from-ghcr.sh
  .github/scripts/validate-deployment-health.sh
  .github/scripts/setup-ghcr-package.sh
  .github/scripts/setup-qwickway-route.sh
  .github/scripts/cleanup-dev-builds.sh
  .env.deploy.example

GitHub Secrets to configure:
  See .env.deploy.example for the full list.
  Add secrets at: https://github.com/<owner>/<repo>/settings/secrets/actions

How to test:
  Push to dev branch to trigger a dev deployment.

How to deploy to UAT:
  Push to main branch.

How to deploy to production:
  Standalone: Create a tag matching v* (e.g., git tag v1.0.0 && git push --tags).
  Monorepo: Create a tag matching <app>-v* (e.g., git tag faabzi-v1.0.0 && git push --tags).
```

Replace `<owner>/<repo>` with the actual GitHub remote if it can be determined from `git remote -v`. Otherwise leave the placeholder.
