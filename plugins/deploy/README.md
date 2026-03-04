# Deploy Plugin

Deployment workflow generator for CapRover apps with QwickWay gateway support.

## What It Does

Generates correct GitHub Actions deployment workflows that fix common pitfalls found in hand-written workflows:

| Bug | Symptom | Fix |
|-----|---------|-----|
| Wrong API for app creation | 404 or silent failure | Uses `/api/v2/user/apps/appDefinitions/register` |
| Health check exits 0 on failure | Deploy reports success, app is down | `validate-deployment-health.sh` exits 1 on failure |
| Errors piped to /dev/null | No error output | All API responses checked and logged |
| No QwickWay gateway | Custom domain returns 404 | `setup-qwickway-route.sh` provisions gateway |
| Missing environments | Only dev or only prod works | All 3 environments (prod, uat, dev) supported |

## Quick Start

```
/setup_workflow
```

The command detects your repo type (standalone or monorepo) and walks you through configuration.

## Architecture

```
route.qwickforge.com (QwickWay gateways)
  |
  |  TARGET_APP = https://<app>.app.qwickforge.com (external URL)
  v
app.qwickforge.com (prod/uat apps)
dev.qwickforge.com (dev apps)
```

- **route.qwickforge.com**: Public-facing QwickWay gateway apps (separate CapRover server)
- **app.qwickforge.com** (OCI_MAIN): Production and UAT apps
- **dev.qwickforge.com** (OCI_DEV): Development apps (per-commit)
- Gateway uses external URLs because apps and gateways are on different Docker swarms

### App Naming

| Env | App (app/dev.qwickforge) | Gateway (route.qwickforge) | Domain |
|-----|--------------------------|---------------------------|--------|
| prod | `<NAME>` | `<NAME>` | example.com |
| uat | `<NAME>-uat` | `<NAME>-uat` | uat.example.com |
| dev | `<NAME>-<sha>` (per commit) | `<NAME>-dev` (latest) | dev.example.com |

## Scripts

All scripts are self-contained bash scripts with `--flag` interfaces. They use `jq` for JSON, retry with exponential backoff on CapRover busy errors, and validate all API responses.

| Script | Source | Description |
|--------|--------|-------------|
| `configure-caprover-app.sh` | Adapted from qwickapps | Provisions app, sets config, env vars (with diff comparison) |
| `deploy-from-ghcr.sh` | Copied from qwickapps | Deploys Docker image from GHCR to CapRover |
| `validate-deployment-health.sh` | Copied from qwickapps | HTTP check + log scan + container status |
| `setup-ghcr-package.sh` | Copied from qwickapps | Configures GHCR package permissions |
| `setup-qwickway-route.sh` | New | Provisions QwickWay gateway on route CapRover |
| `cleanup-dev-builds.sh` | New | Keeps last N dev builds, deletes older ones |

## Workflow Templates

### `deploy-standalone.yml`

For standalone repos (single app, own Dockerfile). Uses `ubuntu-latest` runner.

**Jobs:** build -> deploy-app -> deploy-gateway -> cleanup-dev (dev only)

### `deploy-monorepo-product.yml`

For qwickapps monorepo products. Uses `self-hosted` runner with `zsh` shell.

**Jobs:** build (with build-workspace-package.sh) -> deploy-app -> deploy-gateway -> cleanup-dev

## Required GitHub Secrets

| Secret | Used For | Environment |
|--------|----------|-------------|
| `CAPROVER_URL` | OCI_MAIN CapRover API | prod, uat |
| `CAPROVER_PASSWORD` | OCI_MAIN auth | prod, uat |
| `OCI_DEV_CAPROVER_URL` | OCI_DEV CapRover API | dev |
| `OCI_DEV_CAPROVER_PASSWORD` | OCI_DEV auth | dev |
| `ROUTE_CAPROVER_URL` | Route CapRover API | all |
| `ROUTE_CAPROVER_PASSWORD` | Route CapRover auth | all |
| `GHCR_PULL_TOKEN` | CapRover pulls from GHCR | all |

## Skills

- **provisioning**: CapRover + QwickWay provisioning guidance
- **troubleshooting**: Deployment debugging (common errors, log analysis, rollback)

## Plugin Structure

```
plugins/deploy/
  .claude-plugin/plugin.json
  commands/setup-workflow.md
  skills/
    provisioning/SKILL.md
    troubleshooting/SKILL.md
  scripts/
    configure-caprover-app.sh
    deploy-from-ghcr.sh
    validate-deployment-health.sh
    setup-ghcr-package.sh
    setup-qwickway-route.sh
    cleanup-dev-builds.sh
  templates/
    deploy-standalone.yml
    deploy-monorepo-product.yml
  README.md
```
