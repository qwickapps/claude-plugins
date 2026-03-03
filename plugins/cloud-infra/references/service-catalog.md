# Free Tier Service Catalog

Reference for free SaaS services used alongside OCI free-tier infrastructure.

## Services Overview

| Service | Free Tier | API Key Location | Use Case |
|---------|-----------|-----------------|----------|
| Cloudflare | Unlimited DNS, CDN, DDoS protection | dash.cloudflare.com/profile/api-tokens | DNS + SSL + CDN |
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

## Supabase (Optional)

**Purpose:** Managed PostgreSQL alternative. Use instead of self-hosted oci-db if you prefer managed.

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
