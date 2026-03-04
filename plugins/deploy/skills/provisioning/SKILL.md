---
name: provisioning
description: >
  This skill should be used when setting up CapRover apps and QwickWay gateways
  for deployment, when debugging provisioning issues, or when manually configuring
  deployment infrastructure. Trigger phrases: "provision the app", "set up CapRover",
  "configure the gateway", "create the app on CapRover", "set up QwickWay",
  "deployment infrastructure".
---

# Provisioning

Apply this skill when creating or configuring CapRover apps and QwickWay gateways. Follow each section relevant to the task. Verify API responses at every step — silent failures are the primary cause of provisioning issues.

---

## Architecture Overview

The deployment infrastructure uses three CapRover servers:

| Server | URL | Purpose |
|--------|-----|---------|
| OCI_MAIN | app.qwickforge.com | Hosts prod and uat apps |
| OCI_DEV | dev.qwickforge.com | Hosts dev apps (per-commit) |
| ROUTE | route.qwickforge.com | Hosts QwickWay gateway apps |

Apps on OCI_MAIN and OCI_DEV are not publicly reachable via custom domains directly. The QwickWay gateway on ROUTE proxies inbound requests from custom domains to the apps. Gateways reference apps by their external CapRover URL, because apps and gateways run on separate Docker swarms and cannot communicate via internal hostnames.

```
Custom Domain (DNS)
  |
  v
route.qwickforge.com  <-- QwickWay gateway app
  |
  |  TARGET_APP = https://<app-name>.app.qwickforge.com
  v
app.qwickforge.com    <-- App container
```

---

## App Naming Conventions

Name apps consistently. Do not deviate from these conventions.

| Environment | App name (on app/dev server) | Gateway name (on route server) | Custom domain |
|-------------|------------------------------|-------------------------------|---------------|
| prod | `<NAME>` | `<NAME>` | example.com |
| uat | `<NAME>-uat` | `<NAME>-uat` | uat.example.com |
| dev | `<NAME>-<sha>` (7-char git SHA) | `<NAME>-dev` (single, always points to latest) | dev.example.com |

The dev gateway (`<NAME>-dev`) is not recreated on every commit. It is created once and its `TARGET_APP` env var is updated to point to the latest dev app URL on each deployment.

---

## CapRover App Provisioning

### Authentication

All CapRover API calls require a bearer token obtained from the login endpoint.

```bash
TOKEN=$(curl -s -k -X POST "$CAPROVER_URL/api/v2/login" \
  -H "Content-Type: application/json" \
  -d '{"password":"<password>"}' | jq -r '.data.token')
```

Pass the token as the `x-captain-auth` header on subsequent requests.

### Creating an App

Use the `/api/v2/user/apps/appDefinitions/register` endpoint. This is the correct endpoint for app creation.

```bash
curl -s -k -X POST "$CAPROVER_URL/api/v2/user/apps/appDefinitions/register" \
  -H "Content-Type: application/json" \
  -H "x-captain-auth: $TOKEN" \
  -d '{"appName":"<name>","hasPersistentData":false}'
```

Check `response.status`. A value of `100` is success. Any other value is a failure, even if the HTTP status is 200.

**Common mistake:** Using `/api/v2/user/apps/appData/<name>` for app creation. That endpoint is for deploying images to an existing app, not creating the app definition. Calling it on a non-existent app silently fails or returns a 404.

### Read-Then-Write Pattern for App Configuration

CapRover's app configuration API requires sending the complete app definition, not just the changed fields. Always read the current definition first, merge changes, then write back.

```bash
# Read current definition
APP_DEF=$(curl -s -k "$CAPROVER_URL/api/v2/user/apps/appDefinitions" \
  -H "x-captain-auth: $TOKEN" \
  | jq '.data.appDefinitions[] | select(.appName == "<name>")')

# Merge new values into the definition
UPDATED_DEF=$(echo "$APP_DEF" | jq \
  --arg port "3000" \
  '.containerHttpPort = ($port | tonumber)')

# Write back
curl -s -k -X POST "$CAPROVER_URL/api/v2/user/apps/appDefinitions/update" \
  -H "Content-Type: application/json" \
  -H "x-captain-auth: $TOKEN" \
  -d "$UPDATED_DEF"
```

Skipping the read step causes all unspecified fields to revert to defaults, which can remove env vars, port mappings, and domain configuration.

The `configure-caprover-app.sh` script in `${CLAUDE_PLUGIN_ROOT}/scripts/` implements this pattern with diff comparison to show what changed before writing.

### Environment Variables

Set environment variables by including them in the app definition update. Do not use a separate env var endpoint — the app definition is the source of truth.

```json
{
  "envVars": [
    { "key": "NODE_ENV", "value": "production" },
    { "key": "PORT", "value": "3000" }
  ]
}
```

### Container Port

Set `containerHttpPort` to match the port your application listens on. Mismatches between the configured port and the actual port produce 502 Bad Gateway errors.

### SSL and Domain Configuration

After creating an app, enable the custom domain and force SSL:

```bash
# Add custom domain
curl -s -k -X POST "$CAPROVER_URL/api/v2/user/apps/appDefinitions/customdomain" \
  -H "Content-Type: application/json" \
  -H "x-captain-auth: $TOKEN" \
  -d '{"appName":"<name>","customDomain":"example.com"}'

# Enable SSL (Let's Encrypt)
curl -s -k -X POST "$CAPROVER_URL/api/v2/user/apps/appDefinitions/enablecustomdomainssl" \
  -H "Content-Type: application/json" \
  -H "x-captain-auth: $TOKEN" \
  -d '{"appName":"<name>","customDomain":"example.com"}'

# Force HTTPS in the app definition
# Set forceSsl: true in the app definition update
```

SSL provisioning requires DNS to be pointed at the server before calling `enablecustomdomainssl`. If DNS has not propagated, the Let's Encrypt challenge will fail.

---

## GHCR Registry Credentials

CapRover must be configured with GHCR credentials before it can pull private images. Stale credentials from previous runs cause 500 Internal Server Errors during deploy.

The correct approach:

1. Delete all existing `ghcr.io` registry entries from CapRover.
2. Insert fresh credentials with the current GitHub token.

Do not attempt to update existing entries. Delete and re-insert.

The `deploy-from-ghcr.sh` script in `${CLAUDE_PLUGIN_ROOT}/scripts/` implements this pattern automatically on every deploy.

### Manual credential refresh

```bash
# List registries
curl -s -k "$CAPROVER_URL/api/v2/user/registries" \
  -H "x-captain-auth: $TOKEN" | jq '.data.registries'

# Delete stale entry (repeat for each stale ID)
curl -s -k -X POST "$CAPROVER_URL/api/v2/user/registries/delete" \
  -H "Content-Type: application/json" \
  -H "x-captain-auth: $TOKEN" \
  -d '{"id":"<registry-id>"}'

# Insert fresh credentials
curl -s -k -X POST "$CAPROVER_URL/api/v2/user/registries/insert" \
  -H "Content-Type: application/json" \
  -H "x-captain-auth: $TOKEN" \
  -d '{
    "registryUser":"x-access-token",
    "registryPassword":"<github-token>",
    "registryDomain":"ghcr.io",
    "registryImagePrefix":""
  }'
```

---

## QwickWay Gateway Setup

A QwickWay gateway is a CapRover app running the QwickWay container. It proxies incoming requests to the target app. Gateways live on the ROUTE server, not on OCI_MAIN or OCI_DEV.

### Creating a gateway

1. Create a CapRover app on the ROUTE server using the provisioning steps above.
2. Set two required environment variables in the app definition:
   - `TARGET_APP`: The external HTTPS URL of the destination app (e.g., `https://myapp.app.qwickforge.com`)
   - `HEALTH_CHECK_PATH`: The health check path of the destination app (e.g., `/health`)
3. Configure the custom domain on the gateway app (not on the destination app).
4. Enable SSL on the gateway custom domain.

The `setup-qwickway-route.sh` script in `${CLAUDE_PLUGIN_ROOT}/scripts/` automates gateway creation and updates.

### Updating a gateway's target

For the dev gateway (`<NAME>-dev`), update `TARGET_APP` after each dev deployment to point to the new SHA-tagged app:

```bash
# Read current definition
APP_DEF=$(curl -s -k "$ROUTE_CAPROVER_URL/api/v2/user/apps/appDefinitions" \
  -H "x-captain-auth: $ROUTE_TOKEN" \
  | jq '.data.appDefinitions[] | select(.appName == "<name>-dev")')

# Update TARGET_APP
UPDATED_DEF=$(echo "$APP_DEF" | jq \
  --arg target "https://<name>-<new-sha>.dev.qwickforge.com" \
  '(.envVars[] | select(.key == "TARGET_APP")).value = $target')

# Write back
curl -s -k -X POST "$ROUTE_CAPROVER_URL/api/v2/user/apps/appDefinitions/update" \
  -H "Content-Type: application/json" \
  -H "x-captain-auth: $ROUTE_TOKEN" \
  -d "$UPDATED_DEF"
```

### Architecture note on TARGET_APP URLs

TARGET_APP must use the external CapRover URL for the app (`https://<app>.app.qwickforge.com`), not an internal Docker network address. The ROUTE server and the OCI_MAIN/OCI_DEV servers are on separate Docker swarms and cannot reach each other via Docker internal networking.

---

## Provisioning Checklist

Before marking provisioning complete:

- [ ] App created with `/api/v2/user/apps/appDefinitions/register` (not `/appData/`)
- [ ] App definition read before any configuration write
- [ ] Container port matches the app's actual listening port
- [ ] GHCR credentials refreshed (delete stale, insert fresh)
- [ ] Environment variables set in the app definition
- [ ] Custom domain added and DNS pointed at the server
- [ ] SSL enabled on the custom domain
- [ ] QwickWay gateway created on ROUTE server with correct TARGET_APP
- [ ] Gateway custom domain configured and SSL enabled
- [ ] First deployment verified with `validate-deployment-health.sh`

---

## Scripts Reference

All scripts are located at `${CLAUDE_PLUGIN_ROOT}/scripts/` and are copied to `.github/scripts/` by `/setup_workflow`.

| Script | Purpose |
|--------|---------|
| `configure-caprover-app.sh` | Create or update app definition with diff output |
| `deploy-from-ghcr.sh` | Refresh GHCR credentials and deploy Docker image |
| `validate-deployment-health.sh` | HTTP check, log scan, and container status check |
| `setup-ghcr-package.sh` | Configure GHCR package visibility and repo access |
| `setup-qwickway-route.sh` | Create or update QwickWay gateway on ROUTE server |
| `cleanup-dev-builds.sh` | Delete old SHA-tagged dev apps, keep last N |

All scripts accept `--flag value` arguments, use `jq` for JSON, and validate all API responses.
