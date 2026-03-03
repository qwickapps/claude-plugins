#!/usr/bin/env bash
set -euo pipefail

# ============================================
# OCI Free Tier ARM Capacity Checker
# ============================================
# Checks if your home region has ARM (A1) capacity.
# Does NOT create any resources.
# Prerequisites: oci-cli configured (~/.oci/config)
# ============================================

echo "=== OCI ARM Capacity Checker ==="
echo ""

# Get tenancy and region from OCI config
TENANCY_OCID=$(grep "tenancy" ~/.oci/config | head -1 | cut -d'=' -f2 | tr -d ' ')
REGION=$(grep "region" ~/.oci/config | head -1 | cut -d'=' -f2 | tr -d ' ')

echo "Tenancy: $TENANCY_OCID"
echo "Region:  $REGION"
echo ""

# Root compartment = tenancy for free tier
COMPARTMENT_OCID="$TENANCY_OCID"
echo "[1/3] Using root compartment"

# List availability domains
echo "[2/3] Checking availability domains..."
ADS=$(oci iam availability-domain list \
  --compartment-id "$COMPARTMENT_OCID" \
  --query 'data[*].name' \
  --raw-output 2>/dev/null | tr -d '[]"' | tr ',' '\n' | sed 's/^ *//')

if [ -z "$ADS" ]; then
  echo "ERROR: Could not list availability domains. Check your OCI CLI config."
  exit 1
fi

echo "   Found:"
echo "$ADS" | while read -r ad; do
  [ -z "$ad" ] && continue
  echo "   - $ad"
done
echo ""

# Check ARM shape availability in each AD
echo "[3/3] Checking ARM (VM.Standard.A1.Flex) capacity..."
echo ""

echo "$ADS" | while read -r ad; do
  [ -z "$ad" ] && continue
  echo "   Checking $ad..."

  RESULT=$(oci compute shape list \
    --compartment-id "$COMPARTMENT_OCID" \
    --availability-domain "$ad" \
    --query "data[?shape=='VM.Standard.A1.Flex'].shape" \
    --raw-output 2>/dev/null || echo "ERROR")

  if echo "$RESULT" | grep -q "VM.Standard.A1.Flex"; then
    echo "   >>> ARM capacity AVAILABLE in $ad"
  elif echo "$RESULT" | grep -q "ERROR"; then
    echo "   >>> Could not check (API error)"
  else
    echo "   >>> ARM shape NOT listed in $ad"
  fi
done

echo ""
echo "============================================"
echo "YOUR OCI DETAILS (save these for the AI agent):"
echo "============================================"
echo ""
echo "  OCI_TENANCY_OCID=$TENANCY_OCID"
echo "  OCI_COMPARTMENT_OCID=$COMPARTMENT_OCID"
echo "  OCI_REGION=$REGION"

if [ -f "$HOME/.ssh/id_oci.pub" ]; then
  echo "  SSH_PUBLIC_KEY=$(cat ~/.ssh/id_oci.pub)"
else
  echo "  SSH_PUBLIC_KEY=NOT FOUND -- run: ssh-keygen -t ed25519 -f ~/.ssh/id_oci"
fi

echo ""
echo "If ARM capacity was NOT available:"
echo "  1. Upgrade to Pay-As-You-Go (free-tier resources remain free)"
echo "  2. Try again in a few hours (capacity fluctuates throughout the day)"
echo "  3. The AI agent prompts include automatic retry logic (60s intervals)"
