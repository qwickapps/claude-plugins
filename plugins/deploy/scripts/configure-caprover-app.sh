#!/bin/bash
set -e

# Configure CapRover App Script
# Configures app settings: instance count, ports, SSL, HTTPS, env vars
#
# Uses read-then-write: fetches the full current app definition from CapRover
# before updating, so that only the specified fields are changed and all other
# existing settings (volumes, persistent dirs, custom config, etc.) are preserved.
#
# Enhancement: env var diff comparison. After building the merged definition,
# compares current envVars with desired envVars (sorted by key via jq). If
# identical and --skip-env-if-unchanged is true (default), envVars are removed
# from the update payload so they do not trigger an unnecessary container restart.
#
# Usage:
#   ./configure-caprover-app.sh \
#     --app-name <name> \
#     --caprover-url <url> \
#     --caprover-password <password> \
#     --instance-count <count> \
#     --container-port <port> \
#     --force-ssl <true|false> \
#     --env-file <path> \
#     --skip-env-if-unchanged <true|false>

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
CAPROVER_URL=""
CAPROVER_PASSWORD=""
INSTANCE_COUNT=1
CONTAINER_PORT=3000
FORCE_SSL="true"
ENABLE_SSL="true"
ENV_FILE=""
DOMAINS=""
SKIP_ENV_IF_UNCHANGED="true"

while [[ $# -gt 0 ]]; do
  case $1 in
    --app-name)
      APP_NAME="$2"
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
    --instance-count)
      INSTANCE_COUNT="$2"
      shift 2
      ;;
    --container-port)
      CONTAINER_PORT="$2"
      shift 2
      ;;
    --force-ssl)
      FORCE_SSL="$2"
      shift 2
      ;;
    --enable-ssl)
      ENABLE_SSL="$2"
      shift 2
      ;;
    --env-file)
      ENV_FILE="$2"
      shift 2
      ;;
    --domains)
      DOMAINS="$2"
      shift 2
      ;;
    --skip-env-if-unchanged)
      SKIP_ENV_IF_UNCHANGED="$2"
      shift 2
      ;;
    *)
      echo "Unknown option: $1"
      exit 1
      ;;
  esac
done

# Validate required arguments
if [ -z "$APP_NAME" ] || [ -z "$CAPROVER_URL" ] || [ -z "$CAPROVER_PASSWORD" ]; then
  echo "Error: Missing required arguments"
  exit 1
fi

# Validate boolean arguments
case "$FORCE_SSL" in
  true|false) ;;
  *) echo "Error: --force-ssl must be 'true' or 'false', got '$FORCE_SSL'"; exit 1 ;;
esac

echo "========================================="
echo "Configure CapRover App"
echo "========================================="
echo "App: $APP_NAME"
echo "Instance Count: $INSTANCE_COUNT"
echo "Container Port: $CONTAINER_PORT"
echo "Force SSL: $FORCE_SSL"
echo "Skip Env If Unchanged: $SKIP_ENV_IF_UNCHANGED"
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

if [ -z "$LOGIN_RESPONSE" ] || ! echo "$LOGIN_RESPONSE" | jq -e . >/dev/null 2>&1; then
  echo "Error: CapRover returned non-JSON response (URL: $CAPROVER_URL)"
  exit 1
fi

LOGIN_STATUS=$(echo "$LOGIN_RESPONSE" | jq -r '.status')
if [ "$LOGIN_STATUS" != "100" ]; then
  echo "Error: Authentication failed (status: $LOGIN_STATUS)"
  exit 1
fi

TOKEN=$(echo "$LOGIN_RESPONSE" | jq -r '.data.token')
if [ -z "$TOKEN" ] || [ "$TOKEN" = "null" ]; then
  echo "Error: Failed to extract auth token"
  exit 1
fi
echo "  Authenticated"

# Ensure app exists
echo ""
echo "Ensuring app exists..."
CREATE_RESPONSE=$(curl -s -k -X POST "$CAPROVER_URL/api/v2/user/apps/appDefinitions/register" \
  -H "Content-Type: application/json" \
  -H "x-captain-auth: $TOKEN" \
  -d "$(jq -n --arg name "$APP_NAME" '{appName: $name, hasPersistentData: false}')")

# Check if response is valid JSON
if ! echo "$CREATE_RESPONSE" | jq -e . >/dev/null 2>&1; then
  echo "  Error: Invalid JSON response from CapRover:"
  echo "$CREATE_RESPONSE"
  exit 1
fi

CREATE_STATUS=$(echo "$CREATE_RESPONSE" | jq -r '.status')
APP_ALREADY_EXISTS=false

if [ "$CREATE_STATUS" = "100" ]; then
  echo "  App created"
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

# Enable HTTPS on the base CapRover domain (required before forceSsl can be set)
if [ "$ENABLE_SSL" = "true" ]; then
  echo ""
  echo "Enabling HTTPS on base domain..."
  SSL_RESPONSE=$(caprover_api_call "Enable base domain SSL" \
    curl -s -k -X POST "$CAPROVER_URL/api/v2/user/apps/appDefinitions/enablebasedomainssl" \
    -H "Content-Type: application/json" \
    -H "x-captain-auth: $TOKEN" \
    -d "$(jq -n --arg app "$APP_NAME" '{appName: $app}')")

  SSL_STATUS=$(echo "$SSL_RESPONSE" | jq -r '.status')
  if [ "$SSL_STATUS" = "100" ]; then
    echo "  HTTPS enabled on base domain"
  else
    SSL_DESC=$(echo "$SSL_RESPONSE" | jq -r '.description // "Unknown error"')
    # "already enabled" is not an error
    if echo "$SSL_DESC" | grep -iq "already"; then
      echo "  HTTPS already enabled on base domain"
    else
      echo "  Warning: Could not enable HTTPS: $SSL_DESC"
      echo "  Continuing without forceSsl..."
      FORCE_SSL="false"
    fi
  fi
fi

# Fetch current app definition (read-then-write: preserves all existing fields)
echo ""
echo "Fetching current app definition..."
ALL_DEFS=$(curl -s -k -X GET "$CAPROVER_URL/api/v2/user/apps/appDefinitions" \
  -H "x-captain-auth: $TOKEN")

CURRENT_DEF=$(echo "$ALL_DEFS" | jq --arg name "$APP_NAME" '.data.appDefinitions[] | select(.appName == $name)')

if [ -z "$CURRENT_DEF" ] || [ "$CURRENT_DEF" = "null" ]; then
  echo "  Error: Could not fetch app definition for $APP_NAME"
  exit 1
fi

echo "  Fetched app definition"

# Merge settings into current definition
# Only the specified fields are changed; all other existing settings are preserved
echo ""
echo "Configuring app settings..."
MERGED=$(echo "$CURRENT_DEF" | jq \
  --argjson count "$INSTANCE_COUNT" \
  --argjson port "$CONTAINER_PORT" \
  --argjson ssl "$FORCE_SSL" \
  '.instanceCount = $count | .containerHttpPort = $port | .forceSsl = $ssl | .websocketSupport = true | .appDeployTokenConfig = (.appDeployTokenConfig // {} | .enabled = true)')

# Merge environment variables if env file provided
if [ -n "$ENV_FILE" ] && [ -f "$ENV_FILE" ]; then
  echo ""
  echo "Configuring environment variables from $ENV_FILE..."

  # Read env file and convert to JSON array
  ENV_VARS="[]"
  while IFS= read -r line; do
    # Skip comments and empty lines
    [[ "$line" =~ ^[[:space:]]*#.*$ ]] && continue
    [[ -z "$(echo "$line" | tr -d '[:space:]')" ]] && continue

    # Strip optional 'export ' prefix and leading whitespace
    line=$(echo "$line" | sed 's/^[[:space:]]*//' | sed 's/^export //')

    # Split on first = only
    key="${line%%=*}"
    value="${line#*=}"

    # Skip if no = found
    [ "$key" = "$line" ] && continue

    # Trim whitespace from key
    key=$(echo "$key" | tr -d '[:space:]')

    # Remove surrounding quotes from value if present
    value=$(echo "$value" | sed 's/^["'\'']//' | sed 's/["'\'']$//')

    # Add to JSON array
    ENV_VARS=$(echo "$ENV_VARS" | jq --arg k "$key" --arg v "$value" '. += [{key: $k, value: $v}]')
  done < "$ENV_FILE"

  if [ "$ENV_VARS" != "[]" ]; then
    VAR_COUNT=$(echo "$ENV_VARS" | jq 'length')

    # Env var diff comparison: compare desired vars against current vars.
    # Sort both arrays by key before comparing so order differences are ignored.
    # If identical and --skip-env-if-unchanged is true, omit envVars from the
    # update payload to avoid an unnecessary container restart.
    CURRENT_ENV_SORTED=$(echo "$CURRENT_DEF" | jq -cS '.envVars // [] | sort_by(.key)')
    DESIRED_ENV_SORTED=$(echo "$ENV_VARS" | jq -cS 'sort_by(.key)')

    if [ "$SKIP_ENV_IF_UNCHANGED" = "true" ] && [ "$CURRENT_ENV_SORTED" = "$DESIRED_ENV_SORTED" ]; then
      echo "  Env vars unchanged ($VAR_COUNT vars). Skipping env update to avoid unnecessary restart."
      # Do not set envVars in MERGED; leave the current value intact via the
      # read-then-write approach (CURRENT_DEF already contains the correct envVars).
    else
      MERGED=$(echo "$MERGED" | jq --argjson vars "$ENV_VARS" '.envVars = $vars')
      echo "  Merged $VAR_COUNT environment variables (changes detected, update will apply)"
    fi
  fi
fi

# Write: POST full merged definition back (single call preserves all other fields)
UPDATE_RESPONSE=$(caprover_api_call "Update app" \
  curl -s -k -X POST "$CAPROVER_URL/api/v2/user/apps/appDefinitions/update" \
  -H "Content-Type: application/json" \
  -H "x-captain-auth: $TOKEN" \
  -d "$MERGED")

UPDATE_STATUS=$(echo "$UPDATE_RESPONSE" | jq -r '.status')

if [ "$UPDATE_STATUS" = "100" ] || [ "$UPDATE_STATUS" = "1000" ]; then
  echo "  App settings updated"
else
  UPDATE_DESC=$(echo "$UPDATE_RESPONSE" | jq -r '.description // "Unknown error"')
  echo "  Error: Failed to update app settings: $UPDATE_DESC (status: $UPDATE_STATUS)"
  exit 1
fi

# Configure domains and SSL (only for new apps - existing apps keep their domain config)
if [ "$APP_ALREADY_EXISTS" = "false" ]; then
  if [ -n "$DOMAINS" ]; then
    echo ""
    echo "Configuring domains..."

    IFS=',' read -ra DOMAIN_ARRAY <<< "$DOMAINS"
    for domain in "${DOMAIN_ARRAY[@]}"; do
      domain=$(echo "$domain" | xargs)  # trim whitespace

      echo "  Adding domain: $domain"
      DOMAIN_RESPONSE=$(curl -s -k -X POST "$CAPROVER_URL/api/v2/user/apps/appDefinitions/customdomain" \
        -H "Content-Type: application/json" \
        -H "x-captain-auth: $TOKEN" \
        -d "$(jq -n --arg app "$APP_NAME" --arg dom "$domain" '{appName: $app, customDomain: $dom}')")

      DOMAIN_STATUS=$(echo "$DOMAIN_RESPONSE" | jq -r '.status')
      if [ "$DOMAIN_STATUS" = "100" ]; then
        echo "    Domain added"
      else
        echo "    $(echo "$DOMAIN_RESPONSE" | jq -r '.description')"
      fi
    done

    # Enable SSL per custom domain if requested
    if [ "$ENABLE_SSL" = "true" ]; then
      echo ""
      echo "Enabling SSL..."

      for domain in "${DOMAIN_ARRAY[@]}"; do
        domain=$(echo "$domain" | xargs)
        SSL_RESPONSE=$(curl -s -k -X POST "$CAPROVER_URL/api/v2/user/apps/appDefinitions/enablecustomdomainssl" \
          -H "Content-Type: application/json" \
          -H "x-captain-auth: $TOKEN" \
          -d "$(jq -n --arg app "$APP_NAME" --arg dom "$domain" '{appName: $app, customDomain: $dom}')")

        SSL_STATUS=$(echo "$SSL_RESPONSE" | jq -r '.status')
        if [ "$SSL_STATUS" = "100" ]; then
          echo "  SSL enabled for $domain"
        else
          echo "  $(echo "$SSL_RESPONSE" | jq -r '.description')"
        fi
      done
    fi
  fi
fi

echo ""
echo "========================================="
echo "Configuration complete"
echo "========================================="
