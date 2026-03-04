#!/bin/bash
set -e

# Setup QwickWay Route Script
# Provisions a QwickWay gateway app on a CapRover instance (route.qwickforge.com).
# QwickWay is a reverse proxy that routes traffic from one CapRover server to apps
# on other CapRover servers via external URLs.
#
# Architecture:
#   route.qwickforge.com  - QwickWay gateway apps (public-facing)
#   app.qwickforge.com    - Prod/UAT apps (OCI_MAIN)
#   dev.qwickforge.com    - Dev apps (OCI_DEV)
#
# The gateway uses external URLs for TARGET_APP because the servers are on
# separate Docker swarms and cannot communicate via internal hostnames.
#
# Usage:
#   ./setup-qwickway-route.sh \
#     --gateway-app-name <name> \
#     --target-app-url <url> \
#     --route-caprover-url <url> \
#     --route-caprover-password <password> \
#     --github-token <token> \
#     [--domain <custom-domain>] \
#     [--health-check-path <path>] \
#     [--github-owner <owner>]

# Retry wrapper for CapRover API calls
# Usage: caprover_api_call <description> <curl_command...>
caprover_api_call() {
  local description="$1"
  shift
  local max_retries=5
  local retry_delay=10
  local attempt=1

  while [ $attempt -le $max_retries ]; do
    echo "  Attempt $attempt/$max_retries: $description" >&2

    # Execute curl command and capture response
    local response
    response=$("$@")

    # Check if CapRover is busy
    if echo "$response" | grep -iq "another operation.*in progress\|operation.*still in progress\|please wait"; then
      if [ $attempt -lt $max_retries ]; then
        echo "  CapRover is busy with another operation" >&2
        echo "  Waiting ${retry_delay}s before retry..." >&2
        sleep $retry_delay

        # Exponential backoff: double the delay for next retry (max 60s)
        retry_delay=$((retry_delay * 2))
        if [ $retry_delay -gt 60 ]; then
          retry_delay=60
        fi

        attempt=$((attempt + 1))
        continue
      else
        echo "  CapRover still busy after $max_retries attempts" >&2
        echo "  Response: $response" >&2
        return 1
      fi
    fi

    # Success - return response (to stdout only)
    echo "$response"
    return 0
  done

  # Should never reach here, but just in case
  return 1
}

# Parse arguments
GATEWAY_APP_NAME=""
TARGET_APP_URL=""
ROUTE_CAPROVER_URL=""
ROUTE_CAPROVER_PASSWORD=""
DOMAIN=""
HEALTH_CHECK_PATH="/health"
GITHUB_TOKEN=""
GITHUB_OWNER="qwickapps"

while [[ $# -gt 0 ]]; do
  case $1 in
    --gateway-app-name)
      GATEWAY_APP_NAME="$2"
      shift 2
      ;;
    --target-app-url)
      TARGET_APP_URL="$2"
      shift 2
      ;;
    --route-caprover-url)
      ROUTE_CAPROVER_URL="$2"
      shift 2
      ;;
    --route-caprover-password)
      ROUTE_CAPROVER_PASSWORD="$2"
      shift 2
      ;;
    --domain)
      DOMAIN="$2"
      shift 2
      ;;
    --health-check-path)
      HEALTH_CHECK_PATH="$2"
      shift 2
      ;;
    --github-token)
      GITHUB_TOKEN="$2"
      shift 2
      ;;
    --github-owner)
      GITHUB_OWNER="$2"
      shift 2
      ;;
    *)
      echo "Unknown option: $1"
      exit 1
      ;;
  esac
done

# Validate required arguments
if [ -z "$GATEWAY_APP_NAME" ] || [ -z "$TARGET_APP_URL" ] || [ -z "$ROUTE_CAPROVER_URL" ] || [ -z "$ROUTE_CAPROVER_PASSWORD" ] || [ -z "$GITHUB_TOKEN" ]; then
  echo "Error: Missing required arguments"
  echo "Usage: $0 --gateway-app-name <name> --target-app-url <url> --route-caprover-url <url> --route-caprover-password <password> --github-token <token>"
  exit 1
fi

QWICKWAY_IMAGE="ghcr.io/$GITHUB_OWNER/qwickway:latest"

echo "========================================="
echo "Setup QwickWay Route"
echo "========================================="
echo "Gateway App: $GATEWAY_APP_NAME"
echo "Target URL:  $TARGET_APP_URL"
echo "Route CapRover: $ROUTE_CAPROVER_URL"
echo "Image: $QWICKWAY_IMAGE"
echo "Health Check Path: $HEALTH_CHECK_PATH"
if [ -n "$DOMAIN" ]; then
  echo "Domain: $DOMAIN"
fi
echo "========================================="

# Step 1: Authenticate with route CapRover instance
echo ""
echo "Authenticating with route CapRover..."
set +e
LOGIN_RESPONSE=$(curl -s -k -X POST "$ROUTE_CAPROVER_URL/api/v2/login" \
  -H "Content-Type: application/json" \
  -d "$(jq -n --arg pw "$ROUTE_CAPROVER_PASSWORD" '{password: $pw}')")
CURL_EXIT=$?
set -e

if [ $CURL_EXIT -ne 0 ]; then
  echo "Error: curl failed (exit $CURL_EXIT). Route CapRover may be unreachable (URL: $ROUTE_CAPROVER_URL)"
  exit 1
fi

if [ -z "$LOGIN_RESPONSE" ] || ! echo "$LOGIN_RESPONSE" | jq -e . >/dev/null 2>&1; then
  echo "Error: Route CapRover returned non-JSON response (URL: $ROUTE_CAPROVER_URL)"
  exit 1
fi

LOGIN_STATUS=$(echo "$LOGIN_RESPONSE" | jq -r '.status')
if [ "$LOGIN_STATUS" != "100" ]; then
  echo "Error: Authentication failed with route CapRover (status: $LOGIN_STATUS)"
  exit 1
fi

TOKEN=$(echo "$LOGIN_RESPONSE" | jq -r '.data.token')
if [ -z "$TOKEN" ] || [ "$TOKEN" = "null" ]; then
  echo "  Error: Failed to extract auth token from route CapRover"
  exit 1
fi

echo "  Authenticated"

# Step 2: Register gateway app (idempotent - handles already exists)
echo ""
echo "Registering gateway app..."
CREATE_RESPONSE=$(curl -s -k -X POST "$ROUTE_CAPROVER_URL/api/v2/user/apps/appDefinitions/register" \
  -H "Content-Type: application/json" \
  -H "x-captain-auth: $TOKEN" \
  -d "$(jq -n --arg name "$GATEWAY_APP_NAME" '{appName: $name, hasPersistentData: false}')")

if ! echo "$CREATE_RESPONSE" | jq -e . >/dev/null 2>&1; then
  echo "  Error: Invalid JSON response from CapRover:"
  echo "$CREATE_RESPONSE"
  exit 1
fi

CREATE_STATUS=$(echo "$CREATE_RESPONSE" | jq -r '.status')
APP_ALREADY_EXISTS=false

if [ "$CREATE_STATUS" = "100" ]; then
  echo "  App registered"
  APP_ALREADY_EXISTS=false
elif [ "$CREATE_STATUS" = "1901" ]; then
  echo "  App already exists"
  APP_ALREADY_EXISTS=true
else
  DESC=$(echo "$CREATE_RESPONSE" | jq -r '.description')
  if echo "$DESC" | grep -q "already exists"; then
    echo "  App already exists"
    APP_ALREADY_EXISTS=true
  else
    echo "  Warning: Unexpected response: $DESC"
    APP_ALREADY_EXISTS=false
  fi
fi

# Step 3: Read-then-write: fetch current app definition, merge settings
echo ""
echo "Fetching current app definition..."
ALL_DEFS=$(curl -s -k -X GET "$ROUTE_CAPROVER_URL/api/v2/user/apps/appDefinitions" \
  -H "x-captain-auth: $TOKEN")

CURRENT_DEF=$(echo "$ALL_DEFS" | jq --arg name "$GATEWAY_APP_NAME" '.data.appDefinitions[] | select(.appName == $name)')

if [ -z "$CURRENT_DEF" ] || [ "$CURRENT_DEF" = "null" ]; then
  echo "  Error: Could not fetch app definition for $GATEWAY_APP_NAME"
  exit 1
fi

echo "  Fetched app definition"

# Step 4: Set env vars and container port, merge into existing definition
# TARGET_APP uses the external URL because the route and app servers are on
# separate Docker swarms and cannot communicate via internal hostnames.
echo ""
echo "Configuring env vars and container port..."

ENV_VARS=$(jq -n \
  --arg targetApp "$TARGET_APP_URL" \
  --arg healthPath "$HEALTH_CHECK_PATH" \
  '[{key: "TARGET_APP", value: $targetApp}, {key: "HEALTH_CHECK_PATH", value: $healthPath}]')

MERGED=$(echo "$CURRENT_DEF" | jq \
  --argjson envVars "$ENV_VARS" \
  --argjson port 80 \
  '.envVars = $envVars | .containerHttpPort = $port | .instanceCount = 1 | .forceSsl = true | .websocketSupport = true')

echo "  TARGET_APP=$TARGET_APP_URL"
echo "  HEALTH_CHECK_PATH=$HEALTH_CHECK_PATH"
echo "  Container port: 80"

UPDATE_RESPONSE=$(caprover_api_call "Update app definition" \
  curl -s -k -X POST "$ROUTE_CAPROVER_URL/api/v2/user/apps/appDefinitions/update" \
  -H "Content-Type: application/json" \
  -H "x-captain-auth: $TOKEN" \
  -d "$MERGED")

UPDATE_STATUS=$(echo "$UPDATE_RESPONSE" | jq -r '.status')

if [ "$UPDATE_STATUS" = "100" ] || [ "$UPDATE_STATUS" = "1000" ]; then
  echo "  App definition updated"
else
  echo "  Warning: Update response: $(echo "$UPDATE_RESPONSE" | jq -r '.description')"
fi

# Step 5: Refresh GHCR registry credentials on the route CapRover instance.
# Stale entries from prior runs cause Internal Server Errors on deploy.
echo ""
echo "Refreshing GHCR registry credentials..."

REGISTRIES_RESPONSE=$(curl -s -k -X GET "$ROUTE_CAPROVER_URL/api/v2/user/registries" \
  -H "x-captain-auth: $TOKEN")

# Delete all existing ghcr.io registry entries (may be multiple stale ones)
EXISTING_IDS=$(echo "$REGISTRIES_RESPONSE" | jq -r '.data.registries[] | select(.registryDomain == "ghcr.io") | .id' 2>/dev/null || true)

# Delete stale entries - log results instead of suppressing
if [ -n "$EXISTING_IDS" ]; then
  ENTRY_COUNT=$(echo "$EXISTING_IDS" | wc -l | tr -d ' ')
  echo "  Found $ENTRY_COUNT existing ghcr.io entry/entries - removing stale credentials"
  while IFS= read -r registry_id; do
    [ -z "$registry_id" ] && continue
    DELETE_RESP=$(curl -s -k -X POST "$ROUTE_CAPROVER_URL/api/v2/user/registries/delete" \
      -H "Content-Type: application/json" \
      -H "x-captain-auth: $TOKEN" \
      -d "$(jq -n --arg id "$registry_id" '{id: $id}')")
    DELETE_ST=$(echo "$DELETE_RESP" | jq -r '.status' 2>/dev/null || echo "unknown")
    if [ "$DELETE_ST" != "100" ]; then
      echo "  Warning: Failed to delete registry entry $registry_id (status: $DELETE_ST)"
    fi
  done <<< "$EXISTING_IDS"
fi

# Insert fresh credentials using jq for safe JSON
REGISTRY_PAYLOAD=$(jq -n \
  --arg user "x-access-token" \
  --arg pass "$GITHUB_TOKEN" \
  --arg domain "ghcr.io" \
  '{registryUser: $user, registryPassword: $pass, registryDomain: $domain, registryImagePrefix: ""}')

REGISTRY_RESPONSE=$(caprover_api_call "Insert GHCR registry" \
  curl -s -k -X POST "$ROUTE_CAPROVER_URL/api/v2/user/registries/insert" \
  -H "Content-Type: application/json" \
  -H "x-captain-auth: $TOKEN" \
  -d "$REGISTRY_PAYLOAD")

if ! echo "$REGISTRY_RESPONSE" | jq -e . >/dev/null 2>&1; then
  echo "  Error: CapRover returned invalid JSON when adding credentials"
  echo "  Response: $REGISTRY_RESPONSE"
  exit 1
fi

REGISTRY_STATUS=$(echo "$REGISTRY_RESPONSE" | jq -r '.status')
if [ "$REGISTRY_STATUS" != "100" ]; then
  REGISTRY_DESC=$(echo "$REGISTRY_RESPONSE" | jq -r '.description // "Unknown error"')
  echo "  Error: Failed to add registry credentials: $REGISTRY_DESC (status: $REGISTRY_STATUS)"
  exit 1
fi

echo "  Registry credentials updated"

# Step 6: Deploy ghcr.io/qwickapps/qwickway:latest from GHCR
echo ""
echo "Deploying QwickWay image..."

CAPTAIN_DEFINITION_JSON=$(jq -n \
  --arg imageName "$QWICKWAY_IMAGE" \
  '{schemaVersion: 2, imageName: $imageName}')

DEPLOY_PAYLOAD=$(jq -n \
  --argjson captainDef "$CAPTAIN_DEFINITION_JSON" \
  '{captainDefinitionContent: ($captainDef | tostring)}')

# CapRover deploy can take longer than nginx's proxy_read_timeout (120s),
# causing a 504 Gateway Timeout even though the deploy continues in the
# background and succeeds. Use --max-time 300 to avoid curl hanging
# indefinitely, and treat non-JSON responses as "deploy triggered".
DEPLOY_RESPONSE=$(caprover_api_call "Deploy QwickWay image" \
  curl -s -k --max-time 300 -X POST "$ROUTE_CAPROVER_URL/api/v2/user/apps/appData/$GATEWAY_APP_NAME" \
  -H "Content-Type: application/json" \
  -H "x-captain-auth: $TOKEN" \
  -d "$DEPLOY_PAYLOAD") || true

if ! echo "$DEPLOY_RESPONSE" | jq -e . >/dev/null 2>&1; then
  echo "  Warning: CapRover returned a non-JSON response (likely 504 timeout)"
  echo "  Response (first 5 lines):"
  echo "$DEPLOY_RESPONSE" | head -5
  echo ""
  echo "  The deploy request was sent. CapRover processes deploys"
  echo "  asynchronously, so the deployment likely continues in the"
  echo "  background. The health check step will verify actual status."
else
  DEPLOY_STATUS=$(echo "$DEPLOY_RESPONSE" | jq -r '.status')

  if [ "$DEPLOY_STATUS" != "100" ] && [ "$DEPLOY_STATUS" != "1000" ]; then
    echo "  Error: Deployment failed"
    echo "  Response: $DEPLOY_RESPONSE"
    exit 1
  fi

  echo "  Deployment triggered"
fi

# Step 7: Configure custom domain and SSL (only for new apps)
# Existing apps keep their existing domain configuration.
if [ "$APP_ALREADY_EXISTS" = "false" ] && [ -n "$DOMAIN" ]; then
  echo ""
  echo "Configuring custom domain: $DOMAIN..."

  DOMAIN_RESPONSE=$(curl -s -k -X POST "$ROUTE_CAPROVER_URL/api/v2/user/apps/appDefinitions/customdomain" \
    -H "Content-Type: application/json" \
    -H "x-captain-auth: $TOKEN" \
    -d "$(jq -n --arg app "$GATEWAY_APP_NAME" --arg dom "$DOMAIN" '{appName: $app, customDomain: $dom}')")

  DOMAIN_STATUS=$(echo "$DOMAIN_RESPONSE" | jq -r '.status')
  if [ "$DOMAIN_STATUS" = "100" ]; then
    echo "  Domain added"
  elif [ "$DOMAIN_STATUS" = "1902" ]; then
    echo "  Domain already attached"
  else
    echo "  Warning: $(echo "$DOMAIN_RESPONSE" | jq -r '.description')"
  fi

  echo ""
  echo "Enabling SSL for $DOMAIN..."
  SSL_RESPONSE=$(curl -s -k -X POST "$ROUTE_CAPROVER_URL/api/v2/user/apps/appDefinitions/enablecustomdomainssl" \
    -H "Content-Type: application/json" \
    -H "x-captain-auth: $TOKEN" \
    -d "$(jq -n --arg app "$GATEWAY_APP_NAME" --arg dom "$DOMAIN" '{appName: $app, customDomain: $dom}')")

  SSL_STATUS=$(echo "$SSL_RESPONSE" | jq -r '.status')
  if [ "$SSL_STATUS" = "100" ]; then
    echo "  SSL enabled"
  else
    echo "  Warning: $(echo "$SSL_RESPONSE" | jq -r '.description')"
  fi
fi

# Step 8: Validate gateway health
# Wait for the container to start before checking. CapRover deploys are
# asynchronous; allow up to 60s for the container to become reachable.
echo ""
echo "Validating gateway health..."

# Determine the gateway base URL. Use the custom domain if provided,
# otherwise derive the default CapRover subdomain URL.
if [ -n "$DOMAIN" ]; then
  GATEWAY_BASE_URL="https://$DOMAIN"
else
  # Strip trailing slash from ROUTE_CAPROVER_URL, then build subdomain URL.
  # CapRover uses captain.<root-domain> as its panel URL.
  # Apps are served at <app-name>.<root-domain>.
  CAPROVER_HOST=$(echo "$ROUTE_CAPROVER_URL" | sed 's|https://||' | sed 's|http://||' | sed 's|/||g')
  # Remove the "captain." prefix to get the root domain
  ROOT_DOMAIN=$(echo "$CAPROVER_HOST" | sed 's/^captain\.//')
  GATEWAY_BASE_URL="https://$GATEWAY_APP_NAME.$ROOT_DOMAIN"
fi

GATEWAY_HEALTH_URL="$GATEWAY_BASE_URL/gateway/health"
MAX_WAIT=90
WAIT_INTERVAL=5
ELAPSED=0
HEALTH_OK=false

echo "  Health URL: $GATEWAY_HEALTH_URL"
echo "  Waiting up to ${MAX_WAIT}s for container to start..."

while [ $ELAPSED -lt $MAX_WAIT ]; do
  # Follow redirects (-L) and accept any 2xx or 3xx as healthy.
  # QwickWay may redirect /gateway/health depending on its configuration.
  HTTP_STATUS=$(curl -s -L -o /dev/null -w "%{http_code}" --max-time 10 "$GATEWAY_HEALTH_URL" 2>/dev/null || echo "000")

  if [[ "$HTTP_STATUS" =~ ^[23] ]]; then
    HEALTH_OK=true
    break
  fi

  echo "  HTTP $HTTP_STATUS - waiting ${WAIT_INTERVAL}s (${ELAPSED}s elapsed)..."
  sleep $WAIT_INTERVAL
  ELAPSED=$((ELAPSED + WAIT_INTERVAL))
done

if [ "$HEALTH_OK" = "true" ]; then
  echo "  Gateway health check passed (HTTP $HTTP_STATUS)"
else
  echo "  Warning: Gateway health check did not return 2xx/3xx within ${MAX_WAIT}s"
  echo "  Last HTTP status: $HTTP_STATUS"
  echo "  The container may still be starting. Verify manually: curl -L $GATEWAY_HEALTH_URL"
  exit 1
fi

echo ""
echo "========================================="
echo "QwickWay route setup complete"
echo "========================================="
echo "Gateway App:  $GATEWAY_APP_NAME"
echo "Target URL:   $TARGET_APP_URL"
echo "Gateway URL:  $GATEWAY_BASE_URL"
echo "Health Check: $GATEWAY_HEALTH_URL"
if [ -n "$DOMAIN" ]; then
  echo "Domain:       $DOMAIN"
fi
echo "========================================="
