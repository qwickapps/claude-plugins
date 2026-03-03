# Free Tier Service Catalog

Reference for free SaaS services used alongside OCI free-tier infrastructure.

## Services Overview

| Service | Free Tier | API Key Location | Use Case |
|---------|-----------|-----------------|----------|
| Cloudflare | Unlimited DNS, CDN, DDoS protection | dash.cloudflare.com/profile/api-tokens | DNS + SSL + CDN |
| Cloudflare R2 | 10 GB, zero egress, S3-compatible | dash.cloudflare.com > R2 > API Tokens | Object storage (primary) |
| Neon | Unlimited projects, 0.5 GiB storage, auto-suspend | Console > Connection Details | Primary dev Postgres |
| Supabase | 500 MB DB, 2 projects | Settings > API | Managed Postgres |
| Backblaze B2 | 10 GB, free egress via Cloudflare | secure.backblaze.com > App Keys | Backups, large files |
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

## Cloudflare R2 (Recommended for Storage)

**Purpose:** S3-compatible object storage for user uploads, app assets, product images, documents.

**Why R2 over alternatives:**
- Zero egress fees (S3, GCS, and Firebase charge per GB downloaded -- adds up fast)
- S3-compatible API -- any existing S3 SDK (aws-sdk, @aws-sdk/client-s3) works as-is
- 10 GB permanently free (not a 12-month trial like AWS S3)
- Workers integration for edge image transforms if needed later
- Already on Cloudflare for DNS/CDN, so no new vendor

**Free tier includes:**
- 10 GB storage
- 1,000,000 Class A operations/month (PUT, POST, LIST)
- 10,000,000 Class B operations/month (GET)
- Zero egress fees (permanently)

**Limitations:**
- Requires Cloudflare account with a domain for public bucket access
- No built-in image transformation on free tier (use Workers or client-side)

**Setup requirements:**
1. Cloudflare dashboard > R2 > Create bucket
2. Generate R2 API token (separate from DNS token) with Object Read & Write permissions
3. Collect: Account ID, Access Key ID, Secret Access Key, bucket name

**Environment variables:**
```
R2_ACCOUNT_ID=<cloudflare-account-id>
R2_ACCESS_KEY_ID=<access-key>
R2_SECRET_ACCESS_KEY=<secret-key>
R2_BUCKET_NAME=<bucket-name>
```

**S3-compatible endpoint:** `https://<account-id>.r2.cloudflarestorage.com`
**Public access:** Use a custom domain via R2 > Settings > Custom Domains (Cloudflare handles DNS internally).

**Recommended bucket structure:**
```
my-bucket/
  uploads/          # User-generated content (profile pics, documents)
  assets/           # App assets (logos, product images)
  backups/          # Database dumps, config backups (private)
```

**Use case mapping:**

| Use Case | Solution |
|----------|----------|
| User profile pics, documents | Cloudflare R2 |
| App assets (logos, product images) | Cloudflare R2 (same bucket, `/assets` prefix) |
| Projects already on Supabase | Supabase Storage (keep co-located with DB) |
| Backups, large files, video | Backblaze B2 |

---

## Backblaze B2 (Optional -- Backups and Large Files)

**Purpose:** Cheap bulk storage for backups, large files, video. Pairs with Cloudflare for free egress via the Bandwidth Alliance.

**Free tier includes:**
- 10 GB storage (permanently free)
- Then $0.006/GB/month (very cheap)
- Free egress when paired with Cloudflare (Bandwidth Alliance)

**Limitations:**
- S3-compatible API available but some edge cases differ
- Free tier smaller than R2 for active use
- Best suited for infrequent-access data (backups, archives)

**Setup requirements:**
1. Account at backblaze.com
2. Create a B2 bucket
3. Generate application key with read/write access to the bucket
4. Collect: Key ID, Application Key, bucket name, endpoint

**Environment variables:**
```
B2_KEY_ID=<key-id>
B2_APPLICATION_KEY=<application-key>
B2_BUCKET_NAME=<bucket-name>
B2_ENDPOINT=https://s3.<region>.backblazeb2.com
```

---

## Supabase Storage (Co-Located with Supabase DB)

**Purpose:** File storage for projects already using Supabase as their database. Postgres-native RLS policies apply to files.

**Free tier includes:**
- 1 GB file storage per project
- RLS policies on storage buckets (same auth as database)
- Image transformations (limited on free tier)

**When to use:** Only if the project is already on Supabase for its database. Using Supabase Storage without Supabase DB adds unnecessary complexity.

**No additional setup needed** -- storage is available in the Supabase project dashboard under Storage. Uses the same `SUPABASE_URL` and keys.

---

## Storage Options to Avoid

| Service | Why Avoid |
|---------|-----------|
| AWS S3 | Free tier is 12 months only, then pay. Egress fees add up. |
| Firebase Storage | Google Cloud egress fees hurt at scale. |
| Imgur / Cloudinary free tiers | Too restrictive for production use. |

**Worth watching:** Tigris (5 GB free, S3-compatible, globally distributed, Fly.io add-on). Not included because R2 already covers the same use case with a larger free tier.

---

## Future: Shared Secrets and Topology

Currently, `qwickapps-env.sh` (secrets) and `qwickapps-topology.yml` (infrastructure state) are local files. This limits multi-dev and multi-agent workflows -- a new team member or agent on a different machine has no way to discover what infrastructure exists or access shared credentials.

### Planned: OCI Vault for Secrets

OCI Vault is free on Always Free tier (150 secrets, no cost for storage or API calls). Moving credentials from local env files to Vault enables:
- New devs pull credentials with `oci vault secret get` instead of copying files
- Agents on any machine can access shared credentials programmatically
- Credential rotation updates Vault once; all consumers pull the update
- `qwickapps-env.sh` becomes a local cache that sources from Vault

**OCI Vault free tier:** 150 secrets, 20 master encryption key versions (HSM-backed), no cost for API calls or replication.

**Cloudflare Secrets Store:** 20 secrets free (beta). More limited, oriented toward Workers runtime. Not recommended as primary secrets store.

### Planned: Shared Topology File

`qwickapps-topology.yml` should not be local-only. Options under consideration:
- **Git repo** (most natural): Commit to a private infra repo. Version-controlled, diff-able, accessible to all devs/agents. IPs and OCIDs are not secrets.
- **R2 private bucket**: Accessible via S3 API from any agent with R2 credentials.
- **OCI Object Storage**: 20 GB free, same account as VMs.

The topology file describes infrastructure structure (VMs, IPs, DNS, resource budget), not secrets. Version history is valuable for tracking when infrastructure changes were made.

### Implementation Scope

This is deferred to a future iteration. Current local-file approach works for solo devs. Revisit when:
- Second team member needs infrastructure access
- Automated agents need to discover infrastructure state independently
- Credential rotation becomes a workflow concern

---

## Environment File Template

Save as `qwickapps-env.sh` (do not commit to git):

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

# Cloudflare R2 (recommended for storage)
export R2_ACCOUNT_ID=""
export R2_ACCESS_KEY_ID=""
export R2_SECRET_ACCESS_KEY=""
export R2_BUCKET_NAME=""

# Backblaze B2 (optional -- backups, large files)
# export B2_KEY_ID=""
# export B2_APPLICATION_KEY=""
# export B2_BUCKET_NAME=""

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
