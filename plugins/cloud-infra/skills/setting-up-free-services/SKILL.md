---
name: setting-up-free-services
description: "This skill should be used when setting up free SaaS accounts (Cloudflare R2, Backblaze B2, Supabase, Upstash, Resend) alongside OCI infrastructure. Provides step-by-step guidance for account creation, storage bucket setup, and API key collection. Account creation is manual; this skill collects credentials and saves them. Trigger phrases: 'set up storage', 'configure R2', 'set up Supabase', 'configure Upstash', 'set up Resend', 'free tier services', 'SaaS accounts'."
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
- Cloudflare R2 (recommended -- 10 GB object storage, zero egress, S3-compatible)
- Backblaze B2 (10 GB free, cheap bulk storage for backups and large files)
- Neon (recommended -- managed Postgres, unlimited projects, auto-suspend, branching)
- Supabase (managed Postgres with auth, storage, edge functions)
- Upstash (serverless Redis -- caching, sessions, rate limiting)
- Resend (transactional email -- password resets, notifications)
- All of the above
- None (skip this step)
```

## Cloudflare R2 Setup

**When to use:** Primary object storage for user uploads (profile images, documents) and app assets (logos, product images). Recommended for all deployments.

### Instructions for the User

1. Go to dash.cloudflare.com
2. Click **R2 Object Storage** in the sidebar
3. If prompted, add payment method (required for R2, but free tier has no charges)
4. Click **Create bucket**
5. Name: choose a name (e.g., "myapp-storage" or your domain name)
6. Location: Automatic (or closest to your OCI region)
7. Click **Create bucket**

### Enable Public Access (Optional)

Only enable public access for buckets containing non-sensitive files (app assets, public images). Sensitive user uploads (private documents, personal images) should remain in a private bucket and be served via presigned URLs from your application.

If the bucket needs public read access:

1. In the bucket settings, go to **Settings** tab
2. Under **Custom Domains**, click **Connect Domain**
3. Enter a subdomain (e.g., `cdn.yourdomain.com`)
4. Cloudflare handles the DNS binding internally -- no manual CNAME needed

The R2.dev subdomain is also available under **Public access** but is not recommended for production (no Cloudflare caching, rate-limited).

### Generate R2 API Token

1. In the R2 dashboard, click **Manage R2 API Tokens**
2. Click **Create API token**
3. Token name: "cloud-infra" (or any name)
4. Permissions: **Object Read & Write**
5. Specify bucket: select your bucket (or all buckets)
6. Click **Create API Token**
7. Copy: Access Key ID, Secret Access Key

Also note the **Account ID** from the R2 dashboard URL or the Cloudflare dashboard sidebar.

### Collect Credentials

Ask the user to provide:
- **Account ID**: From the Cloudflare dashboard
- **Access Key ID**: From the R2 API token
- **Secret Access Key**: From the R2 API token (shown only once)
- **Bucket name**: The bucket they created

### Save to Environment File

Ensure the env file has restrictive permissions (credentials in plaintext):

```bash
touch ~/qwickapps-env.sh && chmod 600 ~/qwickapps-env.sh
cat >> ~/qwickapps-env.sh << 'EOF'

# Cloudflare R2
export R2_ACCOUNT_ID="<provided-account-id>"
export R2_ACCESS_KEY_ID="<provided-access-key>"
export R2_SECRET_ACCESS_KEY="<provided-secret-key>"
export R2_BUCKET_NAME="<provided-bucket-name>"
EOF
```

### Verify Connection

```bash
# Verify with the AWS CLI configured for R2 (empty bucket returns no output, which is OK):
aws s3 ls s3://$R2_BUCKET_NAME/ \
  --endpoint-url "https://$R2_ACCOUNT_ID.r2.cloudflarestorage.com" \
  && echo "R2: OK" || echo "R2: FAILED (check credentials and endpoint above)"
```

If the user does not have the AWS CLI, verify from the Cloudflare dashboard instead.

### R2 Notes

- S3-compatible: use `@aws-sdk/client-s3` with the R2 endpoint
- Endpoint: `https://<account-id>.r2.cloudflarestorage.com`
- Zero egress fees permanently -- no surprise bills
- Recommended bucket structure: `/uploads/` for user content, `/assets/` for app assets
- For Supabase projects, use Supabase Storage instead (co-located with DB, RLS applies)

---

## Backblaze B2 Setup

**When to use:** Cheap bulk storage for database backups, large files, or video. Pairs with Cloudflare for free egress via the Bandwidth Alliance.

### Instructions for the User

1. Go to https://www.backblaze.com/sign-up/cloud-storage
2. Sign up with email
3. Click **Create a Bucket**
4. Bucket name: choose a globally unique name (e.g., "myapp-backups")
5. Files in bucket: **Private** (for backups) or **Public** (for served files)
6. Default encryption: **Enable** (required for backup buckets, recommended for all)
7. Click **Create a Bucket**

### Generate Application Key

1. Go to **App Keys** in the B2 dashboard
2. Click **Add a New Application Key**
3. Name: "cloud-infra" (or any name)
4. Allow access to bucket: select your bucket
5. Type of access: **Read and Write**
6. Click **Create New Key**
7. Copy: keyID and applicationKey (shown only once)

### Collect Credentials

Ask the user to provide:
- **Key ID**: The `keyID` from the application key
- **Application Key**: The `applicationKey` (shown only once)
- **Bucket name**: The bucket they created
- **Endpoint**: Shown in bucket details without the scheme (e.g., `s3.us-west-004.backblazeb2.com` -- do not include `https://`, the save step adds it)

### Save to Environment File

```bash
cat >> ~/qwickapps-env.sh << 'EOF'

# Backblaze B2
export B2_KEY_ID="<provided-key-id>"
export B2_APPLICATION_KEY="<provided-application-key>"
export B2_BUCKET_NAME="<provided-bucket-name>"
export B2_ENDPOINT="https://<provided-endpoint>"
EOF
```

### Verify Connection

```bash
aws s3 ls s3://$B2_BUCKET_NAME/ \
  --endpoint-url "$B2_ENDPOINT" \
  && echo "B2: OK" || echo "B2: FAILED (check credentials and endpoint above)"
```

### B2 Notes

- 10 GB free forever, then $0.006/GB/month
- Free egress when served through Cloudflare (Bandwidth Alliance). Direct server-to-bucket downloads (e.g., restoring a backup to an OCI VM) are not covered and incur standard B2 egress at $0.01/GB.
- S3-compatible API
- Best for: database dumps, config backups, large file archives, video storage

---

## Neon Setup

**When to use:** If the user chose Neon as their primary dev database. This is the recommended option for developers running multiple projects.

### Instructions for the User

1. Go to https://console.neon.tech
2. Sign up with GitHub (or email)
3. Create a project for each app (e.g., "faabzi", "qwickbrain", "trinity")
4. For each project, select the region closest to your OCI VMs
5. On the project dashboard, go to **Connection Details**

### Collect Credentials

For each project, ask the user to provide:
- **Connection string**: The full `postgresql://...@...neon.tech/...?sslmode=require` URL

Also collect the Neon API key for CLI operations (branching):
1. Go to https://console.neon.tech/app/settings/api-keys
2. Click "Create new API key"
3. Save as `NEON_API_KEY`

### Install Neon CLI (Optional but Recommended)

The CLI enables database branching for migration testing:

```bash
# macOS
brew install neonctl

# Or via npm
npm install -g neonctl

# Authenticate
neonctl auth
```

### Save to Environment File

```bash
cat >> ~/qwickapps-env.sh << 'EOF'

# Neon
export NEON_API_KEY="<provided-key>"
# Per-project connection strings:
export FAABZI_DATABASE_URL="<provided-connection-string>"
export QWICKBRAIN_DATABASE_URL="<provided-connection-string>"
EOF
```

Adjust the variable names and add more as the user creates projects.

### Verify Connection

```bash
psql "$FAABZI_DATABASE_URL" -c "SELECT version();"
```

Expected: PostgreSQL version string (Neon runs PostgreSQL 16).

### Demonstrate Branching (Optional)

If the user wants to see branching in action:

```bash
# List projects
neonctl projects list

# Create a branch for testing a migration
neonctl branches create --project-id <id> --name test-migration

# Get the branch connection string
neonctl connection-string --project-id <id> --branch test-migration

# Run migrations against the branch (safe -- main DB unaffected)
DATABASE_URL="<branch-url>" npm run migrate

# If migrations succeed, apply to main. If not, delete the branch.
neonctl branches delete --project-id <id> --branch test-migration
```

### Neon Notes

- Free tier: unlimited projects, 0.5 GiB storage each, 100 compute hours/month
- Auto-suspends after 5 min idle (cold start ~1-2s on first query)
- Branching creates instant copy-on-write DB snapshots (no storage duplication)
- Graduation: Neon Pro ($19/month) for 10 GiB storage, autoscaling, more compute

---

## Supabase Setup

**When to use:** If the user chose Supabase. Good for apps that need auth, file storage, or edge functions in addition to a database.

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
cat >> ~/qwickapps-env.sh << 'EOF'

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
cat >> ~/qwickapps-env.sh << 'EOF'

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
cat >> ~/qwickapps-env.sh << 'EOF'

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

Cloudflare R2:
  Bucket: $R2_BUCKET_NAME
  Endpoint: https://$R2_ACCOUNT_ID.r2.cloudflarestorage.com
  Status: [verified/skipped]
  Limits: 10 GB, zero egress

Backblaze B2:
  Bucket: $B2_BUCKET_NAME
  Status: [verified/skipped]
  Limits: 10 GB free, then $0.006/GB

Neon:
  Projects: [list of created projects]
  Status: [verified/skipped]
  CLI: neonctl [installed/not installed]
  Note: Auto-suspends after 5 min idle, 0.5 GiB storage per project

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

Environment file updated: ~/qwickapps-env.sh
```
