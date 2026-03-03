# Free Tier Service Catalog

Reference for free SaaS services used alongside OCI free-tier infrastructure.

## Services Overview

| Service | Free Tier | API Key Location | Use Case |
|---------|-----------|-----------------|----------|
| Cloudflare | Unlimited DNS, CDN, DDoS protection | dash.cloudflare.com/profile/api-tokens | DNS + SSL + CDN |
| Neon | Unlimited projects, 0.5 GiB storage, auto-suspend | Console > Connection Details | Primary dev Postgres |
| Supabase | 500 MB DB, 2 projects | Settings > API | Managed Postgres |
| Upstash | 256 MB, 500K commands/month | Console > Database | Redis cache |
| Resend | 3,000 emails/month, 100/day | API Keys page | Transactional email |
| OCI | 4 OCPU, 24 GB ARM | ~/.oci/config | Compute + storage |

## Cloudflare (Required)

**Purpose:** DNS management, SSL certificates, CDN, DDoS protection.

**Free tier includes:**
- Unlimited DNS records
- Universal SSL certificates (auto-provisioned)
- Basic CDN and caching
- DDoS protection (Layer 3/4)
- 5 page rules

**Setup requirements:**
1. Account at dash.cloudflare.com
2. Domain added and nameservers updated
3. API token with Zone DNS Edit + Zone Read permissions
4. Zone ID (from domain overview sidebar)

**Environment variables:**
```
CLOUDFLARE_DNS_TOKEN=<api-token>
CLOUDFLARE_ZONE_ID=<zone-id>
MY_DOMAIN=<your-domain.com>
```

**API base:** `https://api.cloudflare.com/client/v4`

**Create A record:**
```bash
curl -X POST "https://api.cloudflare.com/client/v4/zones/$CLOUDFLARE_ZONE_ID/dns_records" \
  -H "Authorization: Bearer $CLOUDFLARE_DNS_TOKEN" \
  -H "Content-Type: application/json" \
  --data '{"type":"A","name":"apps","content":"<IP>","proxied":true}'
```

## Neon (Recommended for Dev DB)

**Purpose:** Managed PostgreSQL for development. Replaces the self-hosted oci-db VM, freeing 1 OCPU / 6 GB for apps or AI.

**Why Neon over self-hosted or Supabase:**
- Unlimited projects on free tier (one per app: qwickbrain, faabzi, trinity, etc.)
- Auto-suspend on idle -- no cost, no Oracle idle reclamation concerns
- Database branching -- test migrations on a branch before applying to main
- Upgrade path: Neon Pro ($19/month) or Supabase Pro ($25/month) when an app generates revenue

**Free tier includes:**
- Unlimited projects
- 0.5 GiB storage per project
- 1 compute endpoint per project (auto-suspends after 5 min idle)
- 100 hours of compute per month (shared across projects)
- Branching (create DB branches for migration testing)

**Limitations:**
- 0.5 GiB storage per project (sufficient for dev, not production data)
- Single compute region per project
- Auto-suspend means cold starts (~1-2s on first query after idle)

**Setup requirements:**
1. Account at console.neon.tech (sign up with GitHub)
2. Create a project per app (choose closest region to your OCI VMs)
3. Collect connection string from Connection Details page

**Environment variables:**
```
NEON_API_KEY=<api-key>
DATABASE_URL=postgresql://<user>:<password>@<host>.neon.tech/<dbname>?sslmode=require
```

**Branching workflow:**
```bash
# Create a branch for testing migrations
neonctl branches create --project-id <id> --name migration-test

# Get the branch connection string
neonctl connection-string --project-id <id> --branch migration-test

# Run migrations against the branch
DATABASE_URL="<branch-url>" npm run migrate

# If successful, apply to main branch. If not, delete the branch.
neonctl branches delete --project-id <id> --branch migration-test
```

**Graduation path:**
When an app generates revenue, upgrade to:
- Neon Pro ($19/month): 10 GiB storage, autoscaling, more compute hours
- Supabase Pro ($25/month): 8 GB storage, auth, file storage, edge functions

---

## Supabase (Optional)

**Purpose:** Managed PostgreSQL with extras (auth, file storage, edge functions). Good for prototyping apps that need more than just a database.

**Free tier includes:**
- 2 projects
- 500 MB database storage
- 50,000 monthly active users (auth)
- 1 GB file storage
- 500K edge function invocations/month

**Limitations:**
- Projects pause after 7 days of inactivity (must manually unpause)
- Limited to 2 projects

**Setup requirements:**
1. Account at supabase.com (sign up with GitHub)
2. Create a project in closest region to OCI
3. Collect: Project URL, anon key, service_role key

**Environment variables:**
```
SUPABASE_URL=https://xxxx.supabase.co
SUPABASE_ANON_KEY=<anon-key>
SUPABASE_SERVICE_KEY=<service-role-key>
```

## Upstash (Optional)

**Purpose:** Serverless Redis for caching, sessions, rate limiting, queues.

**Free tier includes:**
- 256 MB data
- 500,000 commands/month
- 10 concurrent connections
- REST API access

**Setup requirements:**
1. Account at console.upstash.com (sign up with GitHub)
2. Create a Redis database in closest region
3. Collect: REST URL and REST token

**Environment variables:**
```
UPSTASH_REDIS_REST_URL=https://xxxx.upstash.io
UPSTASH_REDIS_REST_TOKEN=<token>
```

## Resend (Optional)

**Purpose:** Transactional email (password resets, notifications, receipts).

**Free tier includes:**
- 3,000 emails/month
- 100 emails/day
- 1 custom domain

**Setup requirements:**
1. Account at resend.com (sign up with GitHub)
2. Add and verify your domain (add DNS records via Cloudflare)
3. Create a Full Access API key

**Environment variables:**
```
RESEND_API_KEY=re_xxxx
```

## Environment File Template

Save as `my-cloud-env.sh` (do not commit to git):

```bash
#!/usr/bin/env bash
# === Cloud Environment ===

# OCI
export OCI_TENANCY_OCID="ocid1.tenancy.oc1..xxxx"
export OCI_COMPARTMENT_OCID="$OCI_TENANCY_OCID"
export OCI_REGION="us-ashburn-1"
export OCI_SSH_PUBLIC_KEY_PATH="$HOME/.ssh/id_oci.pub"

# Cloudflare
export CLOUDFLARE_DNS_TOKEN=""
export CLOUDFLARE_ZONE_ID=""
export MY_DOMAIN=""

# Neon (recommended for dev databases)
export NEON_API_KEY=""
# Add per-project DATABASE_URLs as needed:
# export FAABZI_DATABASE_URL="postgresql://...@....neon.tech/faabzi?sslmode=require"
# export QWICKBRAIN_DATABASE_URL="postgresql://...@....neon.tech/qwickbrain?sslmode=require"

# Supabase (optional)
export SUPABASE_URL=""
export SUPABASE_ANON_KEY=""
export SUPABASE_SERVICE_KEY=""

# Upstash (optional)
export UPSTASH_REDIS_REST_URL=""
export UPSTASH_REDIS_REST_TOKEN=""

# Resend (optional)
export RESEND_API_KEY=""

# OpenClaw (optional)
export TELEGRAM_BOT_TOKEN=""
export CLAUDE_OAUTH_TOKEN=""
```
