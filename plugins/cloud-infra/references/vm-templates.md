# VM Templates

Pre-defined VM configurations for Oracle Cloud ARM free tier. All templates use the `VM.Standard.A1.Flex` shape with Ubuntu 22.04 (aarch64).

## Individual Templates

| Template | OCPUs | RAM | Boot Vol | Software | Use Case |
|----------|-------|-----|----------|----------|----------|
| `apps-large` | 2 | 12 GB | 50 GB | CapRover | Multi-app hosting |
| `apps-small` | 1 | 6 GB | 50 GB | CapRover | Single app |
| `db-standard` | 1 | 6 GB | 50 GB | PostgreSQL 16 + pgvector | Database server |
| `ai-assistant` | 1 | 6 GB | 50 GB | OpenClaw + Docker Compose | AI gateway + Telegram |
| `minimal` | 1 | 4 GB | 47 GB | Docker only | Custom use |

## Pre-Built Splits

All splits total 4 OCPU / 24 GB RAM (the full free-tier allocation).

### Full Stack (recommended)

3 VMs covering apps, database, and AI assistant.

| VM Name | Template | OCPUs | RAM | Software |
|---------|----------|-------|-----|----------|
| oci-apps | apps-large | 2 | 12 GB | CapRover |
| oci-db | db-standard | 1 | 6 GB | PostgreSQL 16 + pgvector |
| oci-claw | ai-assistant | 1 | 6 GB | OpenClaw |

**Boot storage:** 150 GB (50 x 3). 50 GB remaining for block volumes.

### Apps Focused

Maximizes app hosting resources. Minimal AI.

| VM Name | Template | OCPUs | RAM | Software |
|---------|----------|-------|-----|----------|
| oci-apps | apps-large | 2 | 12 GB | CapRover |
| oci-db | db-standard | 1 | 6 GB | PostgreSQL 16 + pgvector |
| oci-util | minimal | 1 | 6 GB | Docker only |

**Boot storage:** 147 GB. 53 GB remaining.

### DB Focused

Maximizes database resources. Good for data-heavy workloads.

| VM Name | Template | OCPUs | RAM | Software |
|---------|----------|-------|-----|----------|
| oci-apps | apps-small | 1 | 6 GB | CapRover |
| oci-db | db-standard | 2 | 12 GB | PostgreSQL 16 + pgvector |
| oci-claw | ai-assistant | 1 | 6 GB | OpenClaw |

**Boot storage:** 150 GB. 50 GB remaining.

### Managed DB (recommended for dev)

Uses Neon (or Supabase) instead of a self-hosted database VM. Frees 1 OCPU / 6 GB for a larger apps VM.

| VM Name | Template | OCPUs | RAM | Software |
|---------|----------|-------|-----|----------|
| oci-apps | apps-large | 3 | 18 GB | CapRover |
| oci-claw | ai-assistant | 1 | 6 GB | OpenClaw |

**Boot storage:** 100 GB (50 x 2). 100 GB remaining for block volumes.
**Database:** Neon free tier (unlimited projects, auto-suspend, branching).

**Trade-off:** Database is off-VM. Cold starts (~1-2s) after idle. 0.5 GiB storage per project. Graduate to Neon Pro ($19/month) or Supabase Pro ($25/month) when an app generates revenue.

### Single VM

Everything on one VM. Simplest setup, least isolation.

| VM Name | Template | OCPUs | RAM | Software |
|---------|----------|-------|-----|----------|
| oci-main | (custom) | 4 | 24 GB | Docker Compose: CapRover + PostgreSQL + OpenClaw |

**Boot storage:** 50 GB. 150 GB remaining for block volumes.

**Trade-off:** No isolation between services. A crash or resource spike in one service affects all others. Suitable for personal dev environments only.

## Template Details

### apps-large / apps-small

CapRover PaaS for deploying web apps with automatic SSL.

**Ports required (security list):**
- TCP: 22, 80, 443, 3000, 996, 7946, 4789, 2377
- UDP: 7946, 4789, 2377

**DNS records:**
- `apps.$DOMAIN` -> A record (proxied)
- `*.apps.$DOMAIN` -> A record (DNS only, not proxied)

### db-standard

PostgreSQL 16 with pgvector extension for vector search.

**Ports required (security list):**
- TCP 22 from 0.0.0.0/0 (SSH)
- TCP 5432 from 10.0.0.0/16 only (Postgres, VCN internal)

**DNS records:**
- `db.$DOMAIN` -> A record (DNS only)

**Key config:**
- `shared_buffers`: 25% of RAM
- `effective_cache_size`: 75% of RAM
- `listen_addresses`: `'*'`
- `pg_hba.conf`: allow 10.0.0.0/16 via scram-sha-256

### ai-assistant

OpenClaw AI assistant with Telegram bot integration.

**Ports required (security list):**
- TCP: 22, 80, 443

**DNS records:**
- `claw.$DOMAIN` -> A record (DNS only)

**Prerequisites:**
- Telegram bot token (from @BotFather)
- Claude API key or subscription OAuth token

### minimal

Docker-only VM for custom workloads.

**Ports required (security list):**
- TCP: 22 (add more as needed)

## Custom Splits

The infra-planner agent can generate custom splits for non-standard requirements. Constraints:
- Total OCPUs: max 4
- Total RAM: max 24 GB
- RAM per OCPU: max 6 GB (OCI limit for A1.Flex)
- Boot volume per VM: 47-100 GB (must total <= 200 GB)
- Minimum per VM: 1 OCPU, 1 GB RAM
