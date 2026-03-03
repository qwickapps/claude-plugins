---
name: planning-infrastructure
description: "This skill should be used when gathering cloud infrastructure requirements from the user. It collects information about apps, databases, AI assistants, traffic expectations, and existing accounts, then maps them to VM templates. Supports two modes: interactive questionnaire or plan-file analysis. Trigger phrases: 'plan my infrastructure', 'what VMs do I need', 'cloud setup', 'infrastructure requirements'."
---

# Planning Infrastructure

Collect developer infrastructure requirements and map them to OCI free-tier VM templates.

## Two Modes

### Mode 1: Interactive Questionnaire (Default)

Use AskUserQuestion to collect structured input. Ask these questions in order:

**Question 1 -- App Types**
```
What will you host on your cloud infrastructure?
- Web applications (CapRover PaaS for multiple apps with auto-SSL)
- APIs / backend services only
- Static sites (simple hosting)
- All of the above (recommended)
```

**Question 2 -- Dev/Prod Separation**
```
Do you want separate VMs for production and dev/staging?
- Yes, separate VMs (recommended -- dev builds spike CPU, isolate from prod)
- No, single VM for both (simpler, but dev builds affect prod performance)
```

**Question 3 -- Database**
```
How do you want to handle databases?
- Managed Neon (recommended -- unlimited projects, auto-suspend, branch for migrations)
- Self-hosted PostgreSQL on a dedicated VM (more control, uses 1 OCPU / 6 GB)
- Managed Supabase (500 MB free, 2 projects, pauses after 7 days idle)
- Self-hosted primary + managed for prototyping
- No database needed
```

**Question 4 -- AI Assistant**
```
Do you want an AI assistant (OpenClaw)?
- Yes, with Telegram bot (recommended, 1 OCPU / 6 GB dedicated VM)
- Yes, but co-located with apps (saves a VM, less isolation)
- No AI assistant
```

**Question 5 -- Traffic Level**
```
What traffic level do you expect?
- Hobby / personal dev (low traffic, few users)
- Small team (moderate traffic, 5-20 users)
- Production (higher traffic, needs reliability)
```

**Question 6 -- Existing Accounts**
```
Which accounts do you already have? (select all that apply)
- Oracle Cloud account (with OCI CLI configured)
- Cloudflare account (with a domain added)
- Own a domain name
- None of the above (will set up fresh)
```

### Mode 2: Plan File Analysis

If a file path is provided as argument to `/cloud-setup`:

1. Read the file using the Read tool
2. Extract requirements by analyzing the content:
   - Count mentioned apps, services, APIs
   - Identify database references (PostgreSQL, Redis, Supabase)
   - Look for AI/chatbot/assistant mentions
   - Assess traffic expectations from context
3. Map extracted requirements to the same structure as the questionnaire

Present the extracted requirements to the user for confirmation before proceeding.

## Mapping Requirements to Templates

After collecting requirements, map to VM templates from `${CLAUDE_PLUGIN_ROOT}/references/vm-templates.md`:

| Requirement | Template | Notes |
|-------------|----------|-------|
| Production apps | `apps-large` or `apps-small` | Large if multiple apps or production traffic |
| Dev/staging builds | `dev-server` | Isolated CapRover for frequent deploys |
| Self-hosted PostgreSQL | `db-standard` | 1 OCPU / 6 GB default, 2 OCPU / 12 GB for heavy workloads |
| Managed Neon or Supabase | No VM needed | Frees 1 OCPU / 6 GB for other VMs |
| OpenClaw (dedicated) | `ai-assistant` | 1 OCPU / 6 GB |
| OpenClaw (co-located) | N/A | Installed alongside CapRover on apps VM |
| No specific needs | `minimal` | Docker-only, configure later |

## Output

Pass the structured requirements to the `infra-planner` agent for VM allocation optimization. The requirements object should include:

- `appTypes`: list of app types selected
- `devProdSeparation`: yes or no
- `database`: self-hosted, neon, supabase, both, or none
- `aiAssistant`: dedicated, co-located, or none
- `trafficLevel`: hobby, small-team, or production
- `existingAccounts`: list of accounts already set up
- `additionalNotes`: any context from plan file or user comments

## What Happens Next

After the infra-planner agent returns an allocation, present it to the user for approval. If approved, the `/cloud-setup` command proceeds to pre-flight checks and provisioning.
