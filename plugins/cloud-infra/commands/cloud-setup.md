---
name: cloud-setup
description: "Interactive cloud infrastructure provisioning on Oracle Cloud free tier. Collects requirements, suggests VM allocation, and guides step-by-step setup of CapRover, PostgreSQL, OpenClaw, DNS, and free SaaS services."
argument-hint: "[plan-file-path]"
---

# Cloud Infrastructure Setup

Guided provisioning of Oracle Cloud free-tier infrastructure. Supports two modes:

- **Interactive mode** (default): Asks questions to determine requirements
- **Plan-file mode**: Reads a markdown file describing the project and extracts requirements

## Phase 1: Collect Requirements

**Load skill:** `cloud-infra:planning-infrastructure`

### If argument is a file path:

1. Read the file at the provided path
2. Extract requirements (app types, database needs, AI assistant, traffic level)
3. Present extracted requirements to the user for confirmation
4. Adjust based on user feedback

### If no argument (or argument is a description):

1. Run the interactive questionnaire from the planning-infrastructure skill
2. Collect answers for all 5 questions

## Phase 2: Generate VM Allocation

**Dispatch agent:** `cloud-infra:infra-planner`

Pass the collected requirements to the infra-planner agent. The agent will:

1. Analyze requirements against free-tier limits
2. Match to a pre-built split or generate a custom allocation
3. Return an allocation table with per-VM details

**Present the allocation to the user for approval.** Include:
- VM table (name, OCPUs, RAM, software)
- Resource budget (used vs remaining)
- Per-VM DNS records that will be created
- Risks or considerations

If the user wants changes, adjust the allocation and re-present. Do not proceed without explicit approval.

## Phase 3: Pre-Flight Checks

Run all checks before starting provisioning. Report results clearly.

### Check 1: OCI CLI
```bash
test -f ~/.oci/config && oci iam region list --output table 2>/dev/null | head -5
```
If missing: Guide user through `oci setup config` and API key upload.

### Check 2: SSH Key
```bash
test -f ~/.ssh/id_oci.pub && echo "SSH key: OK" || echo "SSH key: MISSING"
```
If missing: `ssh-keygen -t ed25519 -f ~/.ssh/id_oci -N "" -C "oci-vms"`

### Check 3: Cloudflare Token
```bash
test -n "$CLOUDFLARE_DNS_TOKEN" && curl -s "https://api.cloudflare.com/client/v4/zones/$CLOUDFLARE_ZONE_ID" -H "Authorization: Bearer $CLOUDFLARE_DNS_TOKEN" | jq '.success'
```
If missing: Guide user to create API token at dash.cloudflare.com/profile/api-tokens

### Check 4: Environment File
```bash
test -f ~/my-cloud-env.sh && echo "Env file: OK" || echo "Env file: MISSING"
```
If missing: Create from template in `${CLAUDE_PLUGIN_ROOT}/references/service-catalog.md`

### Check 5: ARM Capacity
```bash
bash ${CLAUDE_PLUGIN_ROOT}/scripts/oci-check-capacity.sh
```

**If any check fails:** Stop and guide the user to fix the issue before continuing. Do not skip pre-flight checks.

**If all checks pass:** Confirm with user before starting provisioning.

## Phase 4: Provisioning

**Load skill:** `cloud-infra:provisioning-oci`

Execute the provisioning steps from the skill. The skill handles:
1. VCN + networking setup (if needed)
2. VM creation for each instance in the allocation
3. Reserved IP assignment
4. SSH config entries
5. Retry logic for capacity errors

Each step requires user confirmation.

## Phase 5: Service Configuration

**Load skill:** `cloud-infra:configuring-services`

For each VM in the allocation, run the matching configuration section:
- Apps VM: CapRover setup
- Database VM: PostgreSQL 16 + pgvector setup
- AI VM: OpenClaw setup

Each configuration step runs via SSH and requires user confirmation.

## Phase 6: DNS Setup

**Load skill:** `cloud-infra:setting-up-dns`

Create Cloudflare DNS records for each VM:
- `apps.$MY_DOMAIN` (proxied) + `*.apps.$MY_DOMAIN` (DNS only)
- `db.$MY_DOMAIN` (DNS only)
- `claw.$MY_DOMAIN` (DNS only)

Only create records for VMs that exist in the allocation.

## Phase 7: Free Services (Optional)

**Load skill:** `cloud-infra:setting-up-free-services`

Ask the user if they want to set up additional free services:
- Supabase (managed Postgres)
- Upstash (Redis)
- Resend (email)

Skip if user declines.

## Phase 8: Post-Setup Verification

Run health checks on all created infrastructure:

```bash
# SSH connectivity
for vm in <vm-names>; do
  ssh -o ConnectTimeout=5 $vm "echo SSH:OK" 2>/dev/null || echo "$vm SSH: FAILED"
done

# CapRover (if apps VM exists)
STATUS=$(curl -s -o /dev/null -w "%{http_code}" "http://apps.${MY_DOMAIN}:3000" 2>/dev/null)
echo "CapRover: HTTP $STATUS"

# PostgreSQL (if db VM exists)
ssh oci-db "pg_isready -h localhost" 2>/dev/null || echo "PostgreSQL: FAILED"

# OpenClaw (if claw VM exists)
ssh oci-claw "cd /opt/openclaw && docker compose ps --format '{{.Status}}'" 2>/dev/null || echo "OpenClaw: FAILED"
```

### Final Summary

Print a complete summary of the infrastructure:

```
=== Cloud Infrastructure Setup Complete ===

VMs:
  oci-apps  (<IP>) - CapRover PaaS
  oci-db    (<IP>) - PostgreSQL 16 + pgvector
  oci-claw  (<IP>) - OpenClaw AI Assistant

URLs:
  CapRover Dashboard: http://apps.$MY_DOMAIN:3000
  CapRover Default Password: captain42 (CHANGE NOW)
  PostgreSQL: postgresql://appuser:<pwd>@<private-ip>:5432/appdb
  OpenClaw: Running (check via: ssh oci-claw "cd /opt/openclaw && docker compose logs --tail 10")

DNS:
  apps.$MY_DOMAIN       -> <IP> (Cloudflare CDN)
  *.apps.$MY_DOMAIN     -> <IP> (wildcard for deployed apps)
  db.$MY_DOMAIN         -> <IP>
  claw.$MY_DOMAIN       -> <IP>

Free Services:
  Supabase: [configured/skipped]
  Upstash:  [configured/skipped]
  Resend:   [configured/skipped]

SSH Access:
  ssh oci-apps
  ssh oci-db
  ssh oci-claw

Next Steps:
  1. Change CapRover password at http://apps.$MY_DOMAIN:3000
  2. Deploy your first app: caprover deploy (or use the dashboard)
  3. Store the PostgreSQL password securely
  4. Test your Telegram bot by sending it a message
```

## Error Handling

At any point during provisioning, if an error occurs:

1. **Stop immediately** -- do not continue to the next step
2. **Present the error** clearly to the user
3. **Suggest fixes** based on the error type:
   - "Out of capacity" -> retry logic in provisioning skill
   - "Authentication error" -> check ~/.oci/config
   - "SSH timeout" -> check security list, instance state
   - "Cloudflare error" -> check API token permissions
4. **Ask the user** how to proceed (retry, skip, or abort)

Never silently skip a failed step. Every failure must be acknowledged and resolved.
