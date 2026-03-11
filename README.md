# QwickApps Claude Code Plugins

Official plugin marketplace for QwickApps development with Claude Code. Six plugins covering the full development lifecycle: SDLC discipline, tech stack guidance, UX design enforcement, cloud infrastructure, deployment automation, and secrets management.

## What's New

**March 2026**
- **secrets** plugin: `github-infra` subcommand for infrastructure-level secrets, env-level naming fixes
- **cloud** plugin: renamed from `cloud-infra`, added storage options (Cloudflare R2, Backblaze B2, Supabase Storage), Neon dev database support, dev/prod VM separation, OCI Vault integration for shared secrets
- Removed `qwickapps-` prefix from all plugin names for cleaner install commands

**February 2026**
- **deploy** plugin: GitHub Actions workflow generator, 6 battle-tested deployment scripts for CapRover/GHCR/QwickWay, parallel workflow support, gateway health checks
- **secrets** plugin: SOPS+age encrypted environment variable management with merge cascade and variable interpolation
- **cloud** plugin: Oracle Cloud free-tier provisioning with interactive planning and guided setup

## Quick Start

```bash
# Add the marketplace
/marketplace add qwickapps/claude-plugins

# Install the plugins you need
/plugins install sdlc           # SDLC workflows and quality gates
/plugins install dev-guide      # Tech stack setup and patterns
/plugins install ux-design      # Design system enforcement
/plugins install cloud          # Oracle Cloud infrastructure provisioning
/plugins install deploy         # CapRover deployment automation
/plugins install secrets        # Encrypted environment variables
```

## Plugins

### sdlc

Complete software development lifecycle management. Issue-driven workflows, quality gates, agent personas, and engineering discipline.

**Commands** (9):

| Command | Purpose |
|---------|---------|
| `/feature` | Full SDLC feature development with issue tracking |
| `/bug` | Bug investigation and fix with regression tests |
| `/refactor` | Code restructuring with behavior preservation |
| `/research` | Deep technical investigation with evidence trail |
| `/review` | Code quality assessment across 5 dimensions |
| `/commit` | Controlled commit with validation gates |
| `/chore` | Maintenance tasks (deps, CI, config) |
| `/docs` | Documentation updates verified against code |
| `/release` | Version bump, changelog, and GitHub release |

**Skills** (23): brainstorming, writing-plans, executing-plans, delegating-tasks, writing-tests, debugging, securing-code, requesting-review, receiving-review, finishing-branch, estimating-effort, optimizing-performance, parallelizing-work, deploying, planning-release, designing-ux, writing-skills, tracking-issues, creating-worktree, starting-sprint, closing-sprint, getting-started, verifying-completion

**Agents** (8): architect, code-reviewer, coder, devops, engineering-manager, product-manager, quality-engineer, tech-writer

**Rules** (10): quality gates covering research depth, fact verification, iteration gates, validation gates, satisfactory criteria, communication protocol, investigation methods, writing style, worktree enforcement, and common patterns

**Hooks**: session-start (loads SDLC context), pre-commit-check (enforces validation gates)

---

### dev-guide

Tech stack selection and per-package patterns for building with the QwickApps platform.

**Skills** (4):

| Skill | Package | What It Covers |
|-------|---------|----------------|
| `use-stack` | -- | Entry point: stack selection, decision tree, unified setup reference |
| `qwickapps-cms` | `@qwickapps/cms` | ServerQwickApp, BlockRenderer, collections, globals, seeds, migrations |
| `qwickapps-server` | `@qwickapps/server` | createGateway, proxy routing, control panel, built-in plugins, route guards |
| `qwickapps-react-framework` | `@qwickapps/react-framework` | QwickApp wrapper, navigation, theme CSS variables, component imports |

**How it works**: Start with `use-stack` to select which components you need. It routes to per-package skills and provides a unified setup reference (`references/qwickapps-full-stack.md`) that resolves overlapping concerns like port scheme, env vars, package.json scripts, and payload.config.ts into a single authoritative source.

**Stack combinations**: Full Product (CMS + Gateway + Framework), CMS Application (no gateway), API Service (gateway only), or add a single component to an existing project.

---

### ux-design

Design system enforcement for `@qwickapps/react-framework`. Preserves full creative freedom while routing all implementation through the framework.

**Skills** (3):

| Skill | Purpose |
|-------|---------|
| `frontend-design` | QwickApps-aware replacement for the built-in frontend-design skill |
| `find-component` | Look up the right framework component before writing JSX |
| `extend-framework` | Add missing components or palettes to the framework |

**Hook**: `enforce-framework-usage` blocks MUI imports, hardcoded colors, and inline styles on every Edit/Write operation.

---

### cloud

Oracle Cloud free-tier infrastructure provisioning. Interactive planning, VM allocation, and guided setup of CapRover, PostgreSQL, OpenClaw, DNS, and free SaaS services.

**Commands** (1): `/cloud-setup` — Interactive infrastructure provisioning wizard

**Skills** (5):

| Skill | Purpose |
|-------|---------|
| `planning-infrastructure` | Gather requirements and map to VM templates |
| `provisioning-oci` | Create VMs via OCI CLI with retry logic |
| `configuring-services` | Install CapRover, PostgreSQL, OpenClaw on VMs |
| `setting-up-dns` | Create Cloudflare DNS records for VMs |
| `setting-up-free-services` | Set up free SaaS accounts (R2, B2, Supabase, Upstash, Resend) |

**Agents** (1): `infra-planner` — Analyzes requirements and suggests optimal VM allocation within free-tier limits

**References**: OCI free-tier limits, service catalog, VM templates

---

### deploy

Deployment workflow generator for CapRover apps with QwickWay gateway integration. Battle-tested scripts and GitHub Actions templates.

**Commands** (1): `/setup_workflow` — Generate GitHub Actions deployment workflow for current repo

**Skills** (2):

| Skill | Purpose |
|-------|---------|
| `provisioning` | Create and configure CapRover apps and QwickWay gateways |
| `troubleshooting` | Diagnose deployment failures, health check issues, gateway problems |

**Scripts** (6): `configure-caprover-app.sh`, `deploy-from-ghcr.sh`, `validate-deployment-health.sh`, `setup-ghcr-package.sh`, `setup-qwickway-route.sh`, `cleanup-dev-builds.sh`

**Templates** (2): `deploy-monorepo-product.yml`, `deploy-standalone.yml` — GitHub Actions workflow templates

---

### secrets

Encrypted environment variable management with SOPS+age. Single `environments.yml` resolves to `.env` files for local dev, GitHub Actions secrets, and CapRover env vars.

**Commands** (2):

| Command | Purpose |
|---------|---------|
| `/secrets` | Manage env vars: list, resolve, local, github, github-infra, caprover, diff, worktree, validate |
| `/secrets-init` | Bootstrap a new repo with `.sops.yaml` and encrypted `environments.yml` |

**Skills** (1): `env-management` — Merge cascade, variable interpolation, `_null` removal, team setup, troubleshooting

**Hooks**: session-start (detects environments.yml and loads context), pre-commit-guard (blocks unencrypted secret files)

## Repository Structure

```
claude-plugins/
  .claude-plugin/
    marketplace.json          # Marketplace registry (6 plugins)
  plugins/
    sdlc/                     # SDLC workflows and discipline
      commands/               # 9 slash commands
      agents/                 # 8 agent personas
      skills/                 # 23 skills
      rules/                  # 10 quality gate rules
      hooks/                  # Session start + pre-commit
      templates/              # Document templates (bug, design, spike, etc.)
    dev-guide/                # Tech stack guidance
      skills/                 # 4 skills (use-stack + 3 per-package)
      scripts/                # Validation utilities
    ux-design/                # Design system enforcement
      skills/                 # 3 skills
      hooks/                  # Framework usage enforcement
    cloud/                    # Oracle Cloud infrastructure
      commands/               # 1 command (cloud-setup)
      agents/                 # 1 agent (infra-planner)
      skills/                 # 5 skills
      references/             # OCI limits, service catalog, VM templates
      scripts/                # Capacity check utility
    deploy/                   # CapRover deployment automation
      commands/               # 1 command (setup-workflow)
      skills/                 # 2 skills
      scripts/                # 6 battle-tested deployment scripts
      templates/              # 2 GitHub Actions workflow templates
    secrets/                  # Encrypted env var management
      commands/               # 2 commands (secrets, secrets-init)
      skills/                 # 1 skill (env-management)
      hooks/                  # Session start + pre-commit guard
      scripts/                # Sync and encryption utilities
      templates/              # Example config files
```

## How the Plugins Work Together

1. **Start work** with `sdlc` commands (`/feature`, `/bug`, etc.) to create issues and follow disciplined workflows
2. **Set up the stack** with `dev-guide` skills when building or extending a QwickApps product
3. **Build the UI** with `ux-design` enforcing design system consistency throughout
4. **Provision infrastructure** with `cloud` for Oracle Cloud free-tier VMs and services
5. **Deploy** with `deploy` to generate GitHub Actions workflows and manage CapRover apps
6. **Manage secrets** with `secrets` to keep environment variables encrypted and in sync

The SDLC plugin provides the process. The dev guide provides the architecture. The UX design plugin provides the guardrails. The cloud, deploy, and secrets plugins handle infrastructure and operations.
