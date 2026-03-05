# VM Templates

Pre-defined VM configurations for Oracle Cloud ARM free tier. All templates use the `VM.Standard.A1.Flex` shape with Ubuntu 22.04 (aarch64).

## Individual Templates

| Template | OCPUs | RAM | Boot Vol | Software | Use Case |
|----------|-------|-----|----------|----------|----------|
| `apps-large` | 2 | 12 GB | 50 GB | CapRover | Multi-app hosting (prod) |
| `apps-small` | 1 | 6 GB | 50 GB | CapRover | Single app or dev builds |
| `dev-server` | 1 | 6 GB | 50 GB | CapRover | Dev/staging builds, isolated from prod |
| `db-standard` | 1 | 6 GB | 50 GB | PostgreSQL 16 + pgvector | Self-hosted database |
| `ai-assistant` | 1 | 6 GB | 50 GB | OpenClaw + Docker Compose | AI gateway + Telegram |
| `minimal` | 1 | 4 GB | 47 GB | Docker only | Custom use |

## Pre-Built Splits

All splits total 4 OCPU / 24 GB RAM (the full free-tier allocation).

### Prod + Dev + AI (recommended)

Separates production from dev builds. Frequent dev deploys cause CPU spikes that could trigger Oracle idle reclamation on the prod VM or degrade production performance. Database on Neon (managed).

| VM Name | Template | OCPUs | RAM | Software | DNS |
|---------|----------|-------|-----|----------|-----|
| oci-main | apps-large | 2 | 12 GB | CapRover | apps.$DOMAIN |
| oci-dev | dev-server | 1 | 6 GB | CapRover | dev.$DOMAIN |
| oci-claw | ai-assistant | 1 | 6 GB | OpenClaw | claw.$DOMAIN |

**Boot storage:** 150 GB (50 x 3). 50 GB remaining.
**Database:** Neon free tier (unlimited projects, one per app).

**Why separate VMs for prod and dev:** Dev instances rebuild multiple times per day. Each build spikes CPU and memory. On a shared VM, this impacts production app response times and risks Oracle flagging the VM as "active but unstable." On a dedicated dev VM, spikes are isolated -- prod stays stable, dev can thrash freely.

### Prod + DB + AI

Self-hosted PostgreSQL instead of managed. Good if you need more than 0.5 GiB storage per DB or want full control over PostgreSQL configuration.

| VM Name | Template | OCPUs | RAM | Software | DNS |
|---------|----------|-------|-----|----------|-----|
| oci-main | apps-large | 2 | 12 GB | CapRover | apps.$DOMAIN |
| oci-db | db-standard | 1 | 6 GB | PostgreSQL 16 + pgvector | db.$DOMAIN |
| oci-claw | ai-assistant | 1 | 6 GB | OpenClaw | claw.$DOMAIN |

**Boot storage:** 150 GB (50 x 3). 50 GB remaining.

### Prod + Dev (no AI)

For developers who do not need OpenClaw. All resources go to app hosting.

| VM Name | Template | OCPUs | RAM | Software | DNS |
|---------|----------|-------|-----|----------|-----|
| oci-main | apps-large | 2 | 12 GB | CapRover | apps.$DOMAIN |
| oci-dev | dev-server | 1 | 6 GB | CapRover | dev.$DOMAIN |
| oci-util | custom | 1 | 6 GB | Docker only | (none) |

**Boot storage:** 147 GB. 53 GB remaining.
**Database:** Neon or Supabase (managed).

### Two VMs Only

Maximum resources per VM. Choose what the second VM does.

| VM Name | Template | OCPUs | RAM | Software | DNS |
|---------|----------|-------|-----|----------|-----|
| oci-main | custom | 3 | 18 GB | CapRover | apps.$DOMAIN |
| oci-claw | ai-assistant | 1 | 6 GB | OpenClaw | claw.$DOMAIN |

**Boot storage:** 100 GB (50 x 2). 100 GB remaining.
**Database:** Neon free tier.

The second VM can be swapped for `dev-server`, `db-standard`, or `minimal` based on what you need.

### Single VM

Everything on one VM. Simplest setup, no isolation.

| VM Name | Template | OCPUs | RAM | Software | DNS |
|---------|----------|-------|-----|----------|-----|
| oci-main | (custom) | 4 | 24 GB | Docker Compose: CapRover + PostgreSQL + OpenClaw | apps.$DOMAIN |

**Boot storage:** 50 GB. 150 GB remaining for block volumes.

**Trade-off:** Dev builds, production traffic, database queries, and AI all compete for the same CPU and RAM. A runaway build can take down production. Only suitable if you have a single low-traffic app.

## Template Details

### apps-large / apps-small

CapRover PaaS for deploying web apps with automatic SSL.

**Ports required (security list):**
- TCP: 22, 80, 443, 3000, 996 from 0.0.0.0/0
- TCP: 7946, 4789, 2377 from 10.0.0.0/16 (Docker Swarm -- VCN internal only)
- UDP: 7946, 4789, 2377 from 10.0.0.0/16 (Docker Swarm -- VCN internal only)

**DNS records:**
- `apps.$DOMAIN` -> A record (proxied)
- `*.apps.$DOMAIN` -> A record (DNS only, not proxied)

### dev-server

CapRover instance for dev/staging builds, isolated from production. Same software as apps-large/apps-small but dedicated to non-production deploys.

**Ports required (security list):**
- TCP: 22, 80, 443, 3000, 996 from 0.0.0.0/0
- TCP: 7946, 4789, 2377 from 10.0.0.0/16 (Docker Swarm -- VCN internal only)
- UDP: 7946, 4789, 2377 from 10.0.0.0/16 (Docker Swarm -- VCN internal only)

**DNS records:**
- `dev.$DOMAIN` -> A record (proxied)
- `*.dev.$DOMAIN` -> A record (DNS only, not proxied)

**Why isolate dev from prod:**
- Dev builds happen multiple times per day and spike CPU/memory
- CPU spikes on a shared VM degrade production response times
- Oracle monitors CPU/memory/network over 7-day windows -- erratic dev spikes mixed with stable prod workloads create unpredictable reclamation risk
- Separate VMs let you restart, rebuild, or break dev without touching prod

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
