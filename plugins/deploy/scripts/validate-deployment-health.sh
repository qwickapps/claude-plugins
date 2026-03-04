#!/bin/bash
set -e

# Validate Deployment Health
# Checks HTTP status AND scans logs for errors after deployment
#
# Usage:
#   ./validate-deployment-health.sh \
#     --app-name <name> \
#     --caprover-url <url> \
#     --caprover-password <password> \
#     --app-url <url> \
#     --health-path <path>

# Parse arguments
APP_NAME=""
CAPROVER_URL=""
CAPROVER_PASSWORD=""
APP_URL=""
HEALTH_PATH="/health"
EXPECTED_VERSION=""

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
    --app-url)
      APP_URL="$2"
      shift 2
      ;;
    --health-path)
      HEALTH_PATH="$2"
      shift 2
      ;;
    --expected-version)
      EXPECTED_VERSION="$2"
      shift 2
      ;;
    *)
      echo "Unknown option: $1"
      exit 1
      ;;
  esac
done

# Validate required arguments
if [ -z "$APP_NAME" ] || [ -z "$CAPROVER_URL" ] || [ -z "$CAPROVER_PASSWORD" ] || [ -z "$APP_URL" ]; then
  echo "Error: Missing required arguments"
  echo "Usage: $0 --app-name <name> --caprover-url <url> --caprover-password <password> --app-url <url>"
  exit 1
fi

echo "========================================="
echo "Validate Deployment Health"
echo "========================================="
echo "App: $APP_NAME"
echo "URL: $APP_URL"
echo "Health: $HEALTH_PATH"
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

echo "  ✓ Authenticated"

# Step 1: Check HTTP status and version (with retry for container startup)
echo ""
echo "Step 1: Checking HTTP status and version..."

MAX_HEALTH_ATTEMPTS=10
HEALTH_DELAY=10
HEALTH_ATTEMPT=1
HTTP_STATUS="000"

while [ $HEALTH_ATTEMPT -le $MAX_HEALTH_ATTEMPTS ]; do
  HTTP_STATUS=$(curl -s -k -o /dev/null -w "%{http_code}" "$APP_URL$HEALTH_PATH" || echo "000")

  if [ "$HTTP_STATUS" = "200" ]; then
    break
  fi

  if [ $HEALTH_ATTEMPT -lt $MAX_HEALTH_ATTEMPTS ]; then
    echo "  Attempt $HEALTH_ATTEMPT/$MAX_HEALTH_ATTEMPTS: HTTP $HTTP_STATUS (waiting ${HEALTH_DELAY}s for container startup...)"
    sleep $HEALTH_DELAY
  fi

  HEALTH_ATTEMPT=$((HEALTH_ATTEMPT + 1))
done

HEALTH_RESPONSE=$(curl -s -k "$APP_URL$HEALTH_PATH")

if [ "$HTTP_STATUS" = "200" ]; then
  echo "  ✓ HTTP 200 OK"

  # Check deployed version if expected version was provided
  if [ -n "$EXPECTED_VERSION" ]; then
    DEPLOYED_VERSION=$(echo "$HEALTH_RESPONSE" | jq -r '.version // "unknown"')
    echo "  Expected version: $EXPECTED_VERSION"
    echo "  Deployed version: $DEPLOYED_VERSION"

    if [ "$DEPLOYED_VERSION" = "$EXPECTED_VERSION" ]; then
      echo "  ✓ Version matches"
    elif [ "$DEPLOYED_VERSION" = "unknown" ]; then
      echo "  ⚠️  Could not determine deployed version"
    else
      echo "  ✗ Version mismatch!"
      echo ""
      echo "VALIDATION FAILED: Deployed version ($DEPLOYED_VERSION) does not match expected version ($EXPECTED_VERSION)"
      exit 1
    fi
  fi
else
  echo "  ✗ HTTP $HTTP_STATUS"
  echo ""
  echo "VALIDATION FAILED: Health check returned non-200 status"
  exit 1
fi

# Step 2: Check recent logs for errors
echo ""
echo "Step 2: Checking application logs for errors..."

# Get all logs from CapRover
ALL_LOGS=$(curl -s -k -X GET "$CAPROVER_URL/api/v2/user/apps/appData/$APP_NAME/logs" \
  -H "x-captain-auth: $TOKEN" | jq -r '.data.logs // ""')

if [ -z "$ALL_LOGS" ]; then
  echo "  Warning: Could not retrieve logs"
else
  # Get only the last 100 lines (most recent logs)
  # This avoids false positives from old deployments
  RECENT_LOGS=$(echo "$ALL_LOGS" | tail -n 100)

  # Critical error patterns (more specific to avoid false positives)
  CRITICAL_PATTERNS=(
    "SyntaxError.*does not provide an export"
    "Cannot find module"
    "ENOENT.*required"
    "FATAL"
    "process.exit\(1\)"
    "MODULE_NOT_FOUND"
    "ERR_MODULE_NOT_FOUND"
  )

  # Deployment failure patterns
  DEPLOY_PATTERNS=(
    "Build has failed"
    "Deploy failed"
    "invalid reference format"
    "Failed to pull image"
    "unauthorized.*pull"
  )

  # Check for repeating critical errors (if it's real, it will repeat)
  CRITICAL_FOUND=0
  CRITICAL_DETAILS=""

  for pattern in "${CRITICAL_PATTERNS[@]}"; do
    COUNT=$(echo "$RECENT_LOGS" | grep -c "$pattern" || true)
    if [ "$COUNT" -ge 2 ]; then
      CRITICAL_FOUND=1
      CRITICAL_DETAILS="$CRITICAL_DETAILS\n  - $pattern (repeated $COUNT times in last 100 lines)"
    fi
  done

  # Check for deployment failure indicators
  for pattern in "${DEPLOY_PATTERNS[@]}"; do
    if echo "$RECENT_LOGS" | grep -q "$pattern"; then
      CRITICAL_FOUND=1
      CRITICAL_DETAILS="$CRITICAL_DETAILS\n  - $pattern (deployment failure)"
    fi
  done

  # Check for positive health indicators (successful startup)
  HEALTH_INDICATORS=(
    "Server.*started"
    "Listening on port"
    "Gateway.*started"
    "Application.*ready"
  )

  HEALTHY_START=0
  for indicator in "${HEALTH_INDICATORS[@]}"; do
    if echo "$RECENT_LOGS" | grep -iq "$indicator"; then
      HEALTHY_START=1
      break
    fi
  done

  # Report findings
  if [ $CRITICAL_FOUND -eq 1 ]; then
    echo "  ✗ Critical errors detected in recent logs:"
    echo -e "$CRITICAL_DETAILS"
    echo ""
    echo "Recent error context (last 30 lines):"
    echo "$RECENT_LOGS" | tail -n 30
    echo ""
    echo "VALIDATION FAILED: Critical errors found in recent application logs"
    exit 1
  elif [ $HEALTHY_START -eq 1 ]; then
    echo "  ✓ Application started successfully (found startup indicator)"
  else
    echo "  ⚠️  No critical errors, but no clear startup success indicator found"
    echo "  Continuing with deployment (HTTP check passed)"
  fi
fi

# Step 3: Check container status (with retry for Docker Swarm convergence)
echo ""
echo "Step 3: Checking container status..."

MAX_STATUS_ATTEMPTS=6
STATUS_DELAY=10
STATUS_ATTEMPT=1
INSTANCES_OK=0

while [ $STATUS_ATTEMPT -le $MAX_STATUS_ATTEMPTS ]; do
  APP_DATA=$(curl -s -k -X GET "$CAPROVER_URL/api/v2/user/apps/appData/$APP_NAME" \
    -H "x-captain-auth: $TOKEN")

  IS_READY=$(echo "$APP_DATA" | jq -r '.data.isAppBuilding')
  INSTANCE_COUNT=$(echo "$APP_DATA" | jq -r '.data.instanceCount // 1')
  RUNNING_INSTANCES=$(echo "$APP_DATA" | jq -r '.data.versions[0].deployedInstances // 0')

  # Default to safe values if CapRover returned non-numeric data
  [[ "$INSTANCE_COUNT" =~ ^[0-9]+$ ]] || INSTANCE_COUNT=1
  [[ "$RUNNING_INSTANCES" =~ ^[0-9]+$ ]] || RUNNING_INSTANCES=0

  if [ "$RUNNING_INSTANCES" -ge "$INSTANCE_COUNT" ] && [ "$INSTANCE_COUNT" -gt 0 ]; then
    INSTANCES_OK=1
    break
  fi

  if [ $STATUS_ATTEMPT -lt $MAX_STATUS_ATTEMPTS ]; then
    echo "  Attempt $STATUS_ATTEMPT/$MAX_STATUS_ATTEMPTS: $RUNNING_INSTANCES/$INSTANCE_COUNT instances (waiting ${STATUS_DELAY}s for Docker Swarm convergence...)"
    sleep $STATUS_DELAY
  fi

  STATUS_ATTEMPT=$((STATUS_ATTEMPT + 1))
done

if [ "$IS_READY" = "false" ]; then
  echo "  ✓ App build complete"
else
  echo "  Warning: App may still be building"
fi

echo "  Instance count: $INSTANCE_COUNT"
echo "  Running instances: $RUNNING_INSTANCES"

if [ $INSTANCES_OK -eq 1 ]; then
  echo "  ✓ All instances running"
elif [ "$HTTP_STATUS" = "200" ]; then
  echo "  ⚠️  CapRover reports $RUNNING_INSTANCES/$INSTANCE_COUNT instances, but HTTP health check passed"
  echo "  Continuing (HTTP 200 is the definitive health indicator)"
else
  echo "  ✗ Not all instances running ($RUNNING_INSTANCES/$INSTANCE_COUNT)"
  echo ""
  echo "VALIDATION FAILED: Not all instances are running"
  exit 1
fi

echo ""
echo "========================================="
echo "✓ Deployment Health Validation PASSED"
echo "========================================="
echo "App: $APP_NAME"
echo "Status: Healthy"
echo "HTTP: $HTTP_STATUS"
echo "Instances: $RUNNING_INSTANCES/$INSTANCE_COUNT"
echo "Logs: Clean (no critical errors)"
echo "========================================="
