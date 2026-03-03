---
name: setting-up-dns
description: "This skill should be used when creating Cloudflare DNS records for OCI VMs. Uses the Cloudflare API to create A records (and wildcard records for CapRover). Handles proxied and DNS-only records. Trigger phrases: 'set up DNS', 'create DNS records', 'configure Cloudflare', 'point domain to VMs'."
---

# Setting Up DNS

Create Cloudflare DNS records pointing your domain to OCI VM public IPs.

<HARD-GATE>
NEVER create or modify DNS records without explicit user confirmation. Present each record, explain what it does, and wait for approval.
</HARD-GATE>

## Prerequisites

Verify before starting:

```bash
# Check Cloudflare credentials are available
test -n "$CLOUDFLARE_DNS_TOKEN" && echo "Token: OK" || echo "Token: MISSING"
test -n "$CLOUDFLARE_ZONE_ID" && echo "Zone ID: OK" || echo "Zone ID: MISSING"
test -n "$MY_DOMAIN" && echo "Domain: $MY_DOMAIN" || echo "Domain: MISSING"
```

If any are missing, guide the user:
1. Log in to dash.cloudflare.com
2. Create an API token with Zone DNS Edit + Zone Read permissions
3. Copy the Zone ID from the domain overview page
4. Set the variables in the environment file

**Verify the token works:**
```bash
curl -s "https://api.cloudflare.com/client/v4/zones/$CLOUDFLARE_ZONE_ID" \
  -H "Authorization: Bearer $CLOUDFLARE_DNS_TOKEN" \
  | jq '.success'
```

Expected: `true`

## DNS Records by VM Type

### App Server (CapRover)

Two records needed:

**1. Main A record (proxied):**
```bash
curl -X POST "https://api.cloudflare.com/client/v4/zones/$CLOUDFLARE_ZONE_ID/dns_records" \
  -H "Authorization: Bearer $CLOUDFLARE_DNS_TOKEN" \
  -H "Content-Type: application/json" \
  --data '{
    "type": "A",
    "name": "apps",
    "content": "<APPS_PUBLIC_IP>",
    "proxied": true,
    "ttl": 1
  }'
```

Result: `apps.$MY_DOMAIN` resolves to the apps VM through Cloudflare CDN.

**2. Wildcard A record (DNS only, NOT proxied):**
```bash
curl -X POST "https://api.cloudflare.com/client/v4/zones/$CLOUDFLARE_ZONE_ID/dns_records" \
  -H "Authorization: Bearer $CLOUDFLARE_DNS_TOKEN" \
  -H "Content-Type: application/json" \
  --data '{
    "type": "A",
    "name": "*.apps",
    "content": "<APPS_PUBLIC_IP>",
    "proxied": false,
    "ttl": 300
  }'
```

Result: `*.apps.$MY_DOMAIN` resolves directly to the apps VM. CapRover uses this wildcard to route deployed apps and provision Let's Encrypt SSL certificates. Must be DNS-only (not proxied) for CapRover's SSL to work.

### Database Server

**A record (DNS only):**
```bash
curl -X POST "https://api.cloudflare.com/client/v4/zones/$CLOUDFLARE_ZONE_ID/dns_records" \
  -H "Authorization: Bearer $CLOUDFLARE_DNS_TOKEN" \
  -H "Content-Type: application/json" \
  --data '{
    "type": "A",
    "name": "db",
    "content": "<DB_PUBLIC_IP>",
    "proxied": false,
    "ttl": 300
  }'
```

Result: `db.$MY_DOMAIN` resolves to the database VM. DNS-only because PostgreSQL uses TCP port 5432 (not HTTP). This record is for SSH access convenience; apps connect via VCN private IP.

### AI Assistant (OpenClaw)

**A record (DNS only):**
```bash
curl -X POST "https://api.cloudflare.com/client/v4/zones/$CLOUDFLARE_ZONE_ID/dns_records" \
  -H "Authorization: Bearer $CLOUDFLARE_DNS_TOKEN" \
  -H "Content-Type: application/json" \
  --data '{
    "type": "A",
    "name": "claw",
    "content": "<CLAW_PUBLIC_IP>",
    "proxied": false,
    "ttl": 300
  }'
```

Result: `claw.$MY_DOMAIN` resolves to the OpenClaw VM.

## Proxied vs DNS-Only

| Record | Proxied | Why |
|--------|---------|-----|
| `apps.$DOMAIN` | Yes | Benefits from Cloudflare CDN, DDoS protection |
| `*.apps.$DOMAIN` | No | CapRover needs direct IP for SSL certificate provisioning |
| `db.$DOMAIN` | No | Non-HTTP traffic (PostgreSQL port 5432) |
| `claw.$DOMAIN` | No | Direct access needed for Telegram webhook |

## Verification

After creating records, verify each one resolves:

```bash
# Check each record
dig +short apps.$MY_DOMAIN
dig +short test.apps.$MY_DOMAIN
dig +short db.$MY_DOMAIN
dig +short claw.$MY_DOMAIN
```

DNS propagation is usually instant with Cloudflare but can take up to 5 minutes.

**List all created records:**
```bash
curl -s "https://api.cloudflare.com/client/v4/zones/$CLOUDFLARE_ZONE_ID/dns_records?type=A" \
  -H "Authorization: Bearer $CLOUDFLARE_DNS_TOKEN" \
  | jq '.result[] | {name, content, proxied, ttl}'
```

## Cleanup

If you need to delete a record (with user confirmation):

```bash
# List records to find the ID
RECORD_ID=$(curl -s "https://api.cloudflare.com/client/v4/zones/$CLOUDFLARE_ZONE_ID/dns_records?name=apps.$MY_DOMAIN" \
  -H "Authorization: Bearer $CLOUDFLARE_DNS_TOKEN" \
  | jq -r '.result[0].id')

# Delete the record
curl -X DELETE "https://api.cloudflare.com/client/v4/zones/$CLOUDFLARE_ZONE_ID/dns_records/$RECORD_ID" \
  -H "Authorization: Bearer $CLOUDFLARE_DNS_TOKEN"
```

## Summary Output

After all records are created:

```
=== DNS Configuration Summary ===

Records Created:
  apps.$MY_DOMAIN       -> <IP> (proxied, Cloudflare CDN)
  *.apps.$MY_DOMAIN     -> <IP> (DNS only, CapRover wildcard)
  db.$MY_DOMAIN         -> <IP> (DNS only)
  claw.$MY_DOMAIN       -> <IP> (DNS only)

Verification:
  [dig output for each record]

CapRover Dashboard: http://apps.$MY_DOMAIN:3000
SSH Access:
  ssh oci-apps  (or: ssh ubuntu@apps.$MY_DOMAIN)
  ssh oci-db    (or: ssh ubuntu@db.$MY_DOMAIN)
  ssh oci-claw  (or: ssh ubuntu@claw.$MY_DOMAIN)
```
