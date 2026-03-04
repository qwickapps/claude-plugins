#!/bin/bash
set -e

# Setup GHCR Package Permissions
# Configures GitHub Container Registry package with proper permissions
#
# Usage:
#   ./setup-ghcr-package.sh \
#     --package-name <name> \
#     --github-owner <owner> \
#     --github-token <token> \
#     --repository <repo>

# Parse arguments
PACKAGE_NAME=""
GITHUB_OWNER="raajkumars"
GITHUB_TOKEN=""
REPOSITORY="qwickapps"

while [[ $# -gt 0 ]]; do
  case $1 in
    --package-name)
      PACKAGE_NAME="$2"
      shift 2
      ;;
    --github-owner)
      GITHUB_OWNER="$2"
      shift 2
      ;;
    --github-token)
      GITHUB_TOKEN="$2"
      shift 2
      ;;
    --repository)
      REPOSITORY="$2"
      shift 2
      ;;
    *)
      echo "Unknown option: $1"
      exit 1
      ;;
  esac
done

# Validate required arguments
if [ -z "$PACKAGE_NAME" ] || [ -z "$GITHUB_TOKEN" ]; then
  echo "Error: Missing required arguments"
  echo "Usage: $0 --package-name <name> --github-token <token>"
  exit 1
fi

echo "========================================="
echo "Setup GHCR Package Permissions"
echo "========================================="
echo "Package: $PACKAGE_NAME"
echo "Owner: $GITHUB_OWNER"
echo "Repository: $REPOSITORY"
echo "========================================="

# GitHub API base URL
API_URL="https://api.github.com"
PACKAGE_URL="$API_URL/user/packages/container/$PACKAGE_NAME"

echo ""
echo "Checking if package exists..."
PACKAGE_CHECK=$(curl -s -w "%{http_code}" -o /tmp/ghcr-package-check.json \
  -H "Authorization: token $GITHUB_TOKEN" \
  -H "Accept: application/vnd.github.v3+json" \
  "$PACKAGE_URL")

if [ "$PACKAGE_CHECK" = "404" ]; then
  echo "  Package does not exist yet - will be created on first push"
  echo "  Note: Permissions will be configured after first image push"
  echo ""
  echo "========================================="
  echo "Next Steps"
  echo "========================================="
  echo "1. Push first Docker image to ghcr.io/$GITHUB_OWNER/$PACKAGE_NAME"
  echo "2. Run this script again to configure permissions"
  echo "========================================="
  exit 0
elif [ "$PACKAGE_CHECK" != "200" ]; then
  echo "  Error: Failed to check package (HTTP $PACKAGE_CHECK)"
  cat /tmp/ghcr-package-check.json
  exit 1
fi

echo "  ✓ Package exists"

echo ""
echo "Configuring repository access..."

# Grant repository write access to the package
REPO_ACCESS_RESPONSE=$(curl -s -w "\n%{http_code}" \
  -X PUT \
  -H "Authorization: token $GITHUB_TOKEN" \
  -H "Accept: application/vnd.github.v3+json" \
  "$PACKAGE_URL/repositories/$REPOSITORY" \
  -d '{"permission":"write"}')

HTTP_CODE=$(echo "$REPO_ACCESS_RESPONSE" | tail -n1)
RESPONSE_BODY=$(echo "$REPO_ACCESS_RESPONSE" | sed '$d')

if [ "$HTTP_CODE" = "204" ] || [ "$HTTP_CODE" = "200" ]; then
  echo "  ✓ Repository access configured (write)"
else
  echo "  Warning: Failed to configure repository access (HTTP $HTTP_CODE)"
  echo "$RESPONSE_BODY" | jq '.' 2>/dev/null || echo "$RESPONSE_BODY"
fi

echo ""
echo "Configuring package visibility..."

# Ensure package is private
VISIBILITY_RESPONSE=$(curl -s -w "\n%{http_code}" \
  -X PATCH \
  -H "Authorization: token $GITHUB_TOKEN" \
  -H "Accept: application/vnd.github.v3+json" \
  "$PACKAGE_URL" \
  -d '{"visibility":"private"}')

HTTP_CODE=$(echo "$VISIBILITY_RESPONSE" | tail -n1)
RESPONSE_BODY=$(echo "$VISIBILITY_RESPONSE" | sed '$d')

if [ "$HTTP_CODE" = "200" ]; then
  echo "  ✓ Package visibility set to private"
else
  echo "  Warning: Failed to set visibility (HTTP $HTTP_CODE)"
  echo "$RESPONSE_BODY" | jq '.' 2>/dev/null || echo "$RESPONSE_BODY"
fi

echo ""
echo "Verifying owner has admin access..."

# Get current package details
PACKAGE_DETAILS=$(curl -s \
  -H "Authorization: token $GITHUB_TOKEN" \
  -H "Accept: application/vnd.github.v3+json" \
  "$PACKAGE_URL")

OWNER_ACCESS=$(echo "$PACKAGE_DETAILS" | jq -r '.owner.login')
if [ "$OWNER_ACCESS" = "$GITHUB_OWNER" ]; then
  echo "  ✓ Owner has admin access"
else
  echo "  Warning: Owner mismatch (expected: $GITHUB_OWNER, got: $OWNER_ACCESS)"
fi

echo ""
echo "========================================="
echo "✓ GHCR Package Setup Complete"
echo "========================================="
echo ""
echo "Package Details:"
echo "  URL: https://github.com/users/$GITHUB_OWNER/packages/container/$PACKAGE_NAME"
echo "  Registry: ghcr.io/$GITHUB_OWNER/$PACKAGE_NAME"
echo "  Visibility: private"
echo "  Repository Access: $REPOSITORY (write)"
echo ""
echo "Next Steps:"
echo "1. Verify settings: https://github.com/users/$GITHUB_OWNER/packages/container/$PACKAGE_NAME/settings"
echo "2. Push Docker image: docker push ghcr.io/$GITHUB_OWNER/$PACKAGE_NAME:tag"
echo "3. Deploy to CapRover using deploy-from-ghcr.sh"
echo ""
