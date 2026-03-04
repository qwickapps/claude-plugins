#!/bin/bash
set -e

# Deploy from GHCR to CapRover
# Configures registry credentials and deploys Docker image from GitHub Container Registry
#
# Usage:
#   ./deploy-from-ghcr.sh \
#     --app-name <name> \
#     --image-ref <ref> \
#     --caprover-url <url> \
#     --caprover-password <password> \
#     --github-token <token> \
#     --github-owner <owner>

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
APP_NAME=""
IMAGE_REF=""
CAPROVER_URL=""
CAPROVER_PASSWORD=""
GITHUB_TOKEN=""
GITHUB_OWNER="qwickapps"

while [[ $# -gt 0 ]]; do
  case $1 in
    --app-name)
      APP_NAME="$2"
      shift 2
      ;;
    --image-ref)
      IMAGE_REF="$2"
      shift 2
      ;;
    --caprover-url)
      CAPROVER_URL="$2"
      shift 2
      ;;
    --caprover-password)
      CAPROVER_PASSWORD="$2"
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
if [ -z "$APP_NAME" ] || [ -z "$IMAGE_REF" ] || [ -z "$CAPROVER_URL" ] || [ -z "$CAPROVER_PASSWORD" ] || [ -z "$GITHUB_TOKEN" ]; then
  echo "Error: Missing required arguments"
  echo "Usage: $0 --app-name <name> --image-ref <ref> --caprover-url <url> --caprover-password <password> --github-token <token>"
  exit 1
fi

echo "========================================="
echo "Deploy from GHCR"
echo "========================================="
echo "App: $APP_NAME"
echo "Image: $IMAGE_REF"
echo "CapRover: $CAPROVER_URL"
echo "========================================="

# Authenticate with CapRover
echo ""
echo "Authenticating with CapRover..."
set +e
LOGIN_RESPONSE=$(curl -s -k -X POST "$CAPROVER_URL/api/v2/login" \
  -H "Content-Type: application/json" \
  -d "$(jq -n --arg pw "$CAPROVER_PASSWORD" '{password: $pw}')")
CURL_EXIT=$?
set -e

if [ $CURL_EXIT -ne 0 ]; then
  echo "Error: curl failed (exit $CURL_EXIT). CapRover may be unreachable (URL: $CAPROVER_URL)"
  exit 1
fi

TOKEN=$(echo "$LOGIN_RESPONSE" | jq -r '.data.token' 2>/dev/null)

if [ -z "$TOKEN" ] || [ "$TOKEN" = "null" ]; then
  echo "Error: Failed to authenticate with CapRover (URL: $CAPROVER_URL)"
  exit 1
fi

echo "  Authenticated"

# Always refresh GHCR registry credentials in CapRover.
# Stale entries from prior runs cause Internal Server Errors on deploy.
echo ""
echo "Refreshing GHCR registry credentials..."

REGISTRIES_RESPONSE=$(curl -s -k -X GET "$CAPROVER_URL/api/v2/user/registries" \
  -H "x-captain-auth: $TOKEN")

# Delete all existing ghcr.io registry entries (may be multiple stale ones)
EXISTING_IDS=$(echo "$REGISTRIES_RESPONSE" | jq -r '.data.registries[] | select(.registryDomain == "ghcr.io") | .id' 2>/dev/null || true)

if [ -n "$EXISTING_IDS" ]; then
  ENTRY_COUNT=$(echo "$EXISTING_IDS" | wc -l | tr -d ' ')
  echo "  Found $ENTRY_COUNT existing ghcr.io entry/entries - removing stale credentials"
  while IFS= read -r registry_id; do
    [ -z "$registry_id" ] && continue
    curl -s -k -X POST "$CAPROVER_URL/api/v2/user/registries/delete" \
      -H "Content-Type: application/json" \
      -H "x-captain-auth: $TOKEN" \
      -d "{\"id\":\"$registry_id\"}" >/dev/null 2>&1 || true
  done <<< "$EXISTING_IDS"
fi

# Insert fresh credentials
REGISTRY_RESPONSE=$(caprover_api_call "Insert GHCR registry" \
  curl -s -k -X POST "$CAPROVER_URL/api/v2/user/registries/insert" \
  -H "Content-Type: application/json" \
  -H "x-captain-auth: $TOKEN" \
  -d "{\"registryUser\":\"x-access-token\",\"registryPassword\":\"$GITHUB_TOKEN\",\"registryDomain\":\"ghcr.io\",\"registryImagePrefix\":\"\"}")

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

# Deploy from Docker image
echo ""
echo "Deploying from Docker image..."

CAPTAIN_DEFINITION_JSON=$(jq -n \
  --arg imageName "$IMAGE_REF" \
  '{schemaVersion: 2, imageName: $imageName}')

DEPLOY_PAYLOAD=$(jq -n \
  --argjson captainDef "$CAPTAIN_DEFINITION_JSON" \
  '{captainDefinitionContent: ($captainDef | tostring)}')

# CapRover deploy can take longer than nginx's proxy_read_timeout (120s),
# causing a 504 Gateway Timeout even though the deploy continues in the
# background and succeeds. Use --max-time 300 to avoid curl hanging
# indefinitely, and treat non-JSON responses as "deploy triggered".
DEPLOY_RESPONSE=$(caprover_api_call "Deploy Docker image" \
  curl -s -k --max-time 300 -X POST "$CAPROVER_URL/api/v2/user/apps/appData/$APP_NAME" \
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
  DEPLOY_DESC=$(echo "$DEPLOY_RESPONSE" | jq -r '.description // ""')

  if [ "$DEPLOY_STATUS" != "100" ] && [ "$DEPLOY_STATUS" != "1000" ]; then
    echo "  Error: Deployment failed"
    echo "  Response: $DEPLOY_RESPONSE"
    exit 1
  fi

  echo "  Deployment triggered successfully"
fi

echo ""
echo "========================================="
echo "Deploy from GHCR complete"
echo "========================================="
echo "Image: $IMAGE_REF"
echo "Next: Health check will verify container started"
echo "========================================="
