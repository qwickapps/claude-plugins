---
name: setting-up-free-services
description: "This skill should be used when setting up free SaaS accounts (Supabase, Upstash, Resend) alongside OCI infrastructure. Provides step-by-step guidance for account creation and API key collection. Account creation is manual; this skill collects credentials and saves them. Trigger phrases: 'set up Supabase', 'configure Upstash', 'set up Resend', 'free tier services', 'SaaS accounts'."
---

# Setting Up Free Services

Guide the user through creating free SaaS accounts and collecting API credentials. Account creation must be done manually by the user -- this skill provides instructions and collects the resulting API keys.

<HARD-GATE>
NEVER create accounts on behalf of the user. All account creation is manual. This skill provides guidance and collects API keys after the user creates accounts.
</HARD-GATE>

## Which Services to Set Up

Reference `${CLAUDE_PLUGIN_ROOT}/references/service-catalog.md` for full details on each service.

Ask the user which services they need:

```
Which free services do you want to set up?
- Supabase (managed Postgres -- good if you skipped self-hosted DB)
- Upstash (serverless Redis -- caching, sessions, rate limiting)
- Resend (transactional email -- password resets, notifications)
- All of the above
- None (skip this step)
```

## Supabase Setup

**When to use:** If the user chose managed Supabase instead of (or in addition to) self-hosted PostgreSQL.

### Instructions for the User

1. Go to https://supabase.com/dashboard
2. Sign up with GitHub (or email)
3. Click "New Project"
4. Choose a project name and strong database password
5. Select the region closest to your OCI home region
6. Wait for the project to provision (1-2 minutes)
7. Go to **Settings > API** in the project dashboard

### Collect Credentials

Ask the user to provide:
- **Project URL**: Shown at the top of the API settings page
- **anon (public) key**: The `anon` key from API settings
- **service_role key**: The `service_role` key (keep secret)

### Save to Environment File

```bash
# Append to the user's environment file
cat >> ~/my-cloud-env.sh << 'EOF'

# Supabase
export SUPABASE_URL="<provided-url>"
export SUPABASE_ANON_KEY="<provided-anon-key>"
export SUPABASE_SERVICE_KEY="<provided-service-key>"
EOF
```

### Verify Connection

```bash
curl -s "$SUPABASE_URL/rest/v1/" \
  -H "apikey: $SUPABASE_ANON_KEY" \
  -H "Authorization: Bearer $SUPABASE_ANON_KEY" \
  | head -c 200
```

Expected: JSON response (empty array or schema info).

### Supabase Notes

- Free tier pauses projects after 7 days of inactivity
- Limited to 2 projects
- 500 MB database storage per project
- Good for prototyping; consider self-hosted PostgreSQL for production

---

## Upstash Setup

**When to use:** If the user needs Redis for caching, session storage, rate limiting, or queues.

### Instructions for the User

1. Go to https://console.upstash.com
2. Sign up with GitHub (or email)
3. Click "Create Database"
4. Name: choose any name (e.g., "myapp-cache")
5. Region: select closest to your OCI region
6. Type: Regional (not Global for free tier)
7. Enable TLS (recommended)
8. Click "Create"
9. On the database page, find the **REST API** section

### Collect Credentials

Ask the user to provide:
- **REST URL**: The `UPSTASH_REDIS_REST_URL` value
- **REST Token**: The `UPSTASH_REDIS_REST_TOKEN` value

### Save to Environment File

```bash
cat >> ~/my-cloud-env.sh << 'EOF'

# Upstash Redis
export UPSTASH_REDIS_REST_URL="<provided-url>"
export UPSTASH_REDIS_REST_TOKEN="<provided-token>"
EOF
```

### Verify Connection

```bash
curl -s "$UPSTASH_REDIS_REST_URL/ping" \
  -H "Authorization: Bearer $UPSTASH_REDIS_REST_TOKEN"
```

Expected: `{"result":"PONG"}`

### Upstash Notes

- 256 MB data limit
- 500,000 commands/month
- 10 concurrent connections
- REST API works from anywhere (no TCP connection needed)

---

## Resend Setup

**When to use:** If the user needs transactional email (password resets, notifications, receipts).

### Instructions for the User

1. Go to https://resend.com/signup
2. Sign up with GitHub (or email)
3. Go to **Domains** > **Add Domain**
4. Enter your domain (e.g., `yourdomain.com`)
5. Resend provides DNS records to add -- create them via Cloudflare:
   - MX record
   - TXT records (SPF, DKIM)
6. Wait for verification (usually 1-5 minutes with Cloudflare)
7. Go to **API Keys** > **Create API Key**
8. Name: "cloud-infra" (or any name)
9. Permission: **Full Access**
10. Copy the API key (shown only once)

### Add DNS Records via Cloudflare

Help the user add the DNS records Resend requires. For each record Resend provides:

```bash
# Example: Add TXT record for SPF
curl -X POST "https://api.cloudflare.com/client/v4/zones/$CLOUDFLARE_ZONE_ID/dns_records" \
  -H "Authorization: Bearer $CLOUDFLARE_DNS_TOKEN" \
  -H "Content-Type: application/json" \
  --data '{
    "type": "TXT",
    "name": "<record-name>",
    "content": "<record-value>",
    "ttl": 300
  }'
```

Present each DNS record to the user for confirmation before creating it.

### Collect Credentials

Ask the user to provide:
- **API Key**: The `re_xxxx` key from Resend

### Save to Environment File

```bash
cat >> ~/my-cloud-env.sh << 'EOF'

# Resend
export RESEND_API_KEY="<provided-key>"
EOF
```

### Verify

```bash
curl -s "https://api.resend.com/domains" \
  -H "Authorization: Bearer $RESEND_API_KEY" \
  | jq '.data[] | {name, status}'
```

Expected: Your domain listed with status "verified".

### Resend Notes

- 3,000 emails/month free
- 100 emails/day limit
- 1 custom domain
- Verify domain DNS records before sending

---

## Summary

After all services are configured:

```
=== Free Services Summary ===

Supabase:
  URL: $SUPABASE_URL
  Status: [verified/skipped]
  Note: Projects pause after 7 days idle

Upstash Redis:
  URL: $UPSTASH_REDIS_REST_URL
  Status: [verified/skipped]
  Limits: 256 MB, 500K commands/month

Resend:
  Domain: $MY_DOMAIN
  Status: [verified/skipped]
  Limits: 3,000 emails/month

Environment file updated: ~/my-cloud-env.sh
```
