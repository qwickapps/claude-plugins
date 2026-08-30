---
name: troubleshooting
description: >
  This skill should be used when deployment fails, health checks don't pass,
  apps don't start, gateway routing is broken, or any deployment-related error
  occurs. Trigger phrases: "deploy failed", "health check failing", "app not
  starting", "502 bad gateway", "deployment error", "CapRover error",
  "container won't start", "can't pull image", "gateway not routing".
---

# Troubleshooting

Follow this skill when a deployment fails or the deployed app is not behaving correctly. Work through each section that matches the observed symptom. Do not skip to fixes — diagnose first.

---

## Diagnostic Principle

Every deployment failure has a specific root cause. Silent failures and misleading success messages are common in CapRover workflows. Gather evidence before acting.

Check in order:
1. CapRover API response — did the operation actually succeed?
2. Application logs — did the container start and run without errors?
3. HTTP health check — is the app responding?
4. Gateway routing — is the custom domain reaching the app?

---

## Common Failures

### 1. Wrong API Endpoint for App Creation

**Symptom:** App creation returns 404, or the app does not appear in the CapRover dashboard after the workflow runs. The workflow may report success because the error was not checked.

**Root cause:** The workflow calls `/api/v2/user/apps/appData/<name>` (the deploy endpoint) instead of `/api/v2/user/apps/appDefinitions/register` (the create endpoint). The deploy endpoint silently ignores requests for apps that do not exist.

**Diagnosis:**

```bash
# Check if the app exists
curl -s -k "$CAPROVER_URL/api/v2/user/apps/appDefinitions" \
  -H "x-captain-auth: $TOKEN" \
  | jq '.data.appDefinitions[] | select(.appName == "<app-name>") | .appName'
```

If nothing is returned, the app was never created.

**Fix:** Use the correct endpoint.

```bash
curl -s -k -X POST "$CAPROVER_URL/api/v2/user/apps/appDefinitions/register" \
  -H "Content-Type: application/json" \
  -H "x-captain-auth: $TOKEN" \
  -d '{"appName":"<name>","hasPersistentData":false}'
```

Check that `response.status` is `100` before proceeding.

---

### 2. Health Check Exits 0 When App Is Down

**Symptom:** The workflow reports the deployment as successful, but the app is not accessible. Requests to the app URL return errors. CapRover may show the app as deployed.

**Root cause:** The health check step in the workflow uses a command that always exits 0 (success), regardless of whether the HTTP response was 200 or an error. Common patterns that silently swallow failures:
- `curl` without `-f` or without checking `$?`
- Exit code piped to `/dev/null`
- Health check result stored in a variable but never evaluated

**Diagnosis:**

```bash
# Run the health check manually and check the exit code
curl -f -s "$APP_URL/health"
echo "Exit code: $?"

# Also check the HTTP status code explicitly
HTTP_STATUS=$(curl -s -o /dev/null -w "%{http_code}" "$APP_URL/health")
echo "HTTP status: $HTTP_STATUS"
```

If the exit code is 0 but the status is not 200, the health check script is not failing correctly.

**Fix:** Use `validate-deployment-health.sh` from `${CLAUDE_PLUGIN_ROOT}/scripts/`. It checks HTTP status, scans logs for critical errors, checks container status, and exits 1 on any failure.

```bash
.github/scripts/validate-deployment-health.sh \
  --app-name "$APP_NAME" \
  --caprover-url "$CAPROVER_URL" \
  --caprover-password "$CAPROVER_PASSWORD" \
  --app-url "https://$APP_DOMAIN" \
  --health-path "/health"
```

---

### 3. Errors Piped to /dev/null (Silent Failures)

**Symptom:** No error output in the workflow logs, but the deployment does not work. Each step appears to succeed. The actual problem is invisible.

**Root cause:** API responses or command output are redirected to `/dev/null`, or errors are suppressed with `|| true` without logging the failure. The workflow runs to completion even when each step fails.

**Diagnosis:** Add explicit response logging to each CapRover API call:

```bash
RESPONSE=$(curl -s -k -X POST "$CAPROVER_URL/api/v2/user/apps/appDefinitions/register" \
  -H "Content-Type: application/json" \
  -H "x-captain-auth: $TOKEN" \
  -d '{"appName":"<name>","hasPersistentData":false}')

echo "Response: $RESPONSE"

STATUS=$(echo "$RESPONSE" | jq -r '.status')
if [ "$STATUS" != "100" ]; then
  echo "Error: operation failed with status $STATUS"
  exit 1
fi
```

**Fix:** Audit every API call in the workflow. Every call must:
- Capture the response body
- Check `response.status` equals `100`
- Exit non-zero if the check fails
- Never pipe to `/dev/null` without logging

The scripts in `${CLAUDE_PLUGIN_ROOT}/scripts/` apply this pattern consistently.

---

### 4. Missing QwickWay Gateway

**Symptom:** The custom domain (e.g., myapp.example.com) returns 404 or cannot be reached, but the app itself is healthy when accessed via its CapRover subdomain (e.g., `https://myapp.app.qwickforge.com`).

**Root cause:** No QwickWay gateway app exists on the ROUTE server for this domain, or the gateway exists but `TARGET_APP` points to the wrong URL.

**Diagnosis:**

```bash
# Authenticate with ROUTE server
ROUTE_TOKEN=$(curl -s -k -X POST "$ROUTE_CAPROVER_URL/api/v2/login" \
  -H "Content-Type: application/json" \
  -d '{"password":"<route-password>"}' | jq -r '.data.token')

# Check if gateway app exists
curl -s -k "$ROUTE_CAPROVER_URL/api/v2/user/apps/appDefinitions" \
  -H "x-captain-auth: $ROUTE_TOKEN" \
  | jq '.data.appDefinitions[] | select(.appName == "<name>") | {appName, envVars}'
```

Check that:
- The gateway app exists on ROUTE
- `TARGET_APP` is set to `https://<app-name>.app.qwickforge.com` (external URL, not internal)
- The custom domain is configured on the gateway (not on the app itself)
- DNS points the custom domain at the ROUTE server

**Fix:** Create or update the gateway using `setup-qwickway-route.sh` from `${CLAUDE_PLUGIN_ROOT}/scripts/`.

---

### 5. Missing Environments

**Symptom:** Deployments work for one environment but not others. For example, dev deploys succeed but prod does not, or UAT was never set up.

**Root cause:** The workflow only provisions one environment. The app and gateway creation steps were run once and not applied to all environments.

**Diagnosis:** Check which apps exist on each server.

```bash
# OCI_MAIN (prod + uat)
curl -s -k "$CAPROVER_URL/api/v2/user/apps/appDefinitions" \
  -H "x-captain-auth: $TOKEN" \
  | jq '[.data.appDefinitions[].appName]'

# OCI_DEV (dev)
curl -s -k "$OCI_DEV_CAPROVER_URL/api/v2/user/apps/appDefinitions" \
  -H "x-captain-auth: $OCI_DEV_TOKEN" \
  | jq '[.data.appDefinitions[].appName]'

# ROUTE (gateways)
curl -s -k "$ROUTE_CAPROVER_URL/api/v2/user/apps/appDefinitions" \
  -H "x-captain-auth: $ROUTE_TOKEN" \
  | jq '[.data.appDefinitions[].appName]'
```

**Fix:** Run the provisioning steps for each missing environment. The `/setup_workflow` command generates workflows that provision all three environments.

---

### 6. GHCR Registry Credentials Stale

**Symptom:** CapRover returns a 500 Internal Server Error or "unauthorized" during the deploy step. The image exists in GHCR but CapRover cannot pull it.

**Root cause:** CapRover caches GHCR credentials from a previous deployment. When the GitHub token rotates (e.g., it was a short-lived Actions token from a prior run), the cached credentials are no longer valid. CapRover does not automatically detect this and returns a server error.

**Diagnosis:**

```bash
# List current registries in CapRover
curl -s -k "$CAPROVER_URL/api/v2/user/registries" \
  -H "x-captain-auth: $TOKEN" \
  | jq '.data.registries[] | select(.registryDomain == "ghcr.io") | {id, registryUser}'
```

If multiple ghcr.io entries appear, they are stale duplicates.

**Fix:** Delete all existing ghcr.io entries and insert fresh credentials. The `deploy-from-ghcr.sh` script in `${CLAUDE_PLUGIN_ROOT}/scripts/` does this automatically. To fix manually:

```bash
# Delete stale entries (repeat for each ID). Field name is "registryId", not
# "id" -- "id" silently returns {"status":1111,"description":"Registry not
# found"} even for an entry that clearly exists.
curl -s -k -X POST "$CAPROVER_URL/api/v2/user/registries/delete" \
  -H "Content-Type: application/json" \
  -H "x-captain-auth: $TOKEN" \
  -d '{"registryId":"<registry-id>"}'

# Insert fresh credentials
curl -s -k -X POST "$CAPROVER_URL/api/v2/user/registries/insert" \
  -H "Content-Type: application/json" \
  -H "x-captain-auth: $TOKEN" \
  -d '{
    "registryUser":"x-access-token",
    "registryPassword":"<current-github-token>",
    "registryDomain":"ghcr.io",
    "registryImagePrefix":""
  }'
```

---

### 7. Container Port Mismatch

**Symptom:** The app is deployed and running, but requests return 502 Bad Gateway. The CapRover health check shows the container is up.

**Root cause:** The `containerHttpPort` in the CapRover app definition does not match the port the application actually listens on. CapRover proxies traffic to the wrong port, which is not listening, and returns 502.

**Diagnosis:**

```bash
# Check the configured port in the app definition
curl -s -k "$CAPROVER_URL/api/v2/user/apps/appDefinitions" \
  -H "x-captain-auth: $TOKEN" \
  | jq '.data.appDefinitions[] | select(.appName == "<name>") | .containerHttpPort'

# Check what port the app actually listens on
# Look at the application's Dockerfile EXPOSE statement
# Or check the app's port configuration (PORT env var, server.listen() call, etc.)
```

**Fix:** Update the app definition to match the actual listening port.

```bash
APP_DEF=$(curl -s -k "$CAPROVER_URL/api/v2/user/apps/appDefinitions" \
  -H "x-captain-auth: $TOKEN" \
  | jq '.data.appDefinitions[] | select(.appName == "<name>")')

UPDATED_DEF=$(echo "$APP_DEF" | jq \
  --argjson port 3000 \
  '.containerHttpPort = $port')

curl -s -k -X POST "$CAPROVER_URL/api/v2/user/apps/appDefinitions/update" \
  -H "Content-Type: application/json" \
  -H "x-captain-auth: $TOKEN" \
  -d "$UPDATED_DEF"
```

Redeploy after updating the port.

---

### 8. Image Not Found

**Symptom:** The deploy step fails with "invalid reference format", "manifest unknown", or "not found". The image cannot be pulled.

**Root cause:** The image reference in the deploy payload points to an image that does not exist in GHCR. Common causes:
- The build job failed or was skipped, so the image was never pushed
- The image tag in the deploy step does not match the tag used during build
- The image was pushed to the wrong GHCR organization or repo

**Diagnosis:**

```bash
# Check what image reference the deploy step is using
# Look at the workflow log output for the deploy step

# Verify the image exists in GHCR
curl -s \
  -H "Authorization: token $GITHUB_TOKEN" \
  "https://api.github.com/orgs/<owner>/packages/container/<package>/versions" \
  | jq '.[0:5] | [.[] | {id, name: .metadata.container.tags}]'
```

Also confirm the build job log shows "Successfully pushed" before the deploy job runs.

**Fix:**
- Verify the build job succeeded and pushed the image.
- Confirm the image tag in the deploy step matches the tag used in the build step. Both should reference `${{ github.sha }}` for consistency.
- Confirm the GHCR organization in the image reference matches the actual package location.

---

## Checking CapRover Logs via API

Retrieve application logs to diagnose startup errors without accessing the CapRover dashboard.

```bash
# Get logs for an app
LOGS=$(curl -s -k "$CAPROVER_URL/api/v2/user/apps/appData/$APP_NAME/logs" \
  -H "x-captain-auth: $TOKEN" \
  | jq -r '.data.logs // "No logs returned"')

echo "$LOGS" | tail -n 50
```

Look for:
- `Cannot find module` — missing dependency or wrong build artifact
- `MODULE_NOT_FOUND` / `ERR_MODULE_NOT_FOUND` — ESM/CJS resolution error
- `ENOENT` — missing file at expected path
- `SyntaxError` — broken JavaScript/TypeScript in the deployed bundle
- `FATAL` — application-level fatal error
- `process.exit(1)` — intentional shutdown
- `Build has failed` — CapRover-level build error
- `invalid reference format` — bad image reference
- `unauthorized` — registry authentication failure

Startup success indicators:
- `Server started`
- `Listening on port`
- `Gateway started`
- `Application ready`

If none of the startup indicators appear and there are no fatal errors, the app may still be building. Wait 30 seconds and check again.

---

## Verifying Gateway Routing

After confirming the app is healthy on its CapRover subdomain, verify the gateway is routing correctly.

```bash
# Check app health directly (bypasses gateway)
curl -f "https://<app-name>.app.qwickforge.com/health"

# Check via custom domain (through gateway)
curl -f "https://myapp.example.com/health"

# Check gateway TARGET_APP configuration
ROUTE_TOKEN=$(curl -s -k -X POST "$ROUTE_CAPROVER_URL/api/v2/login" \
  -H "Content-Type: application/json" \
  -d '{"password":"<route-password>"}' | jq -r '.data.token')

curl -s -k "$ROUTE_CAPROVER_URL/api/v2/user/apps/appDefinitions" \
  -H "x-captain-auth: $ROUTE_TOKEN" \
  | jq '.data.appDefinitions[] | select(.appName == "<gateway-name>") | .envVars'
```

Confirm `TARGET_APP` is the external CapRover URL of the app, not an internal address.

---

## Manual Rollback

To roll back to a previous deployment, redeploy the previous image tag.

```bash
# Find the previous image tag (use the git SHA of the last known-good commit)
PREVIOUS_SHA=abc1234

# Redeploy
.github/scripts/deploy-from-ghcr.sh \
  --app-name "$APP_NAME" \
  --image-ref "ghcr.io/<owner>/<image>:$PREVIOUS_SHA" \
  --caprover-url "$CAPROVER_URL" \
  --caprover-password "$CAPROVER_PASSWORD" \
  --github-token "$GITHUB_TOKEN" \
  --github-owner "<owner>"

# Verify
.github/scripts/validate-deployment-health.sh \
  --app-name "$APP_NAME" \
  --caprover-url "$CAPROVER_URL" \
  --caprover-password "$CAPROVER_PASSWORD" \
  --app-url "https://$APP_DOMAIN" \
  --health-path "/health"
```

Images are retained in GHCR as long as the package is not cleaned up. Identify the correct SHA from the git log or the GHCR package version list before rolling back.

---

## Troubleshooting Checklist

Work through this list when a deployment is broken:

- [ ] Checked CapRover API response status for each step (must be `100`)
- [ ] Verified app exists on the correct CapRover server
- [ ] Ran `validate-deployment-health.sh` and reviewed its output
- [ ] Checked application logs via CapRover API for startup errors
- [ ] Confirmed `containerHttpPort` matches the app's actual listening port
- [ ] Confirmed GHCR credentials are fresh (delete stale, insert current)
- [ ] Confirmed image reference matches the tag used during build
- [ ] Confirmed gateway exists on ROUTE server with correct `TARGET_APP`
- [ ] Confirmed custom domain DNS points to the correct server
- [ ] Confirmed SSL is enabled on the custom domain

If all items pass and the app is still not working, retrieve the full application logs and inspect the last 100 lines for any repeated error pattern.
