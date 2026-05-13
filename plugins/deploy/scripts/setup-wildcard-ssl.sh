#!/bin/bash
# setup-wildcard-ssl.sh
#
# Sets up a Let's Encrypt wildcard certificate on a CapRover server using
# DNS-01 challenge via Cloudflare. Creates sync script, cron job, and
# renewal hook so all CapRover apps use the wildcard cert automatically.
#
# Usage:
#   bash setup-wildcard-ssl.sh \
#     --server oci-dev \
#     --domain dev.qwickforge.com \
#     --cloudflare-token <CLOUDFLARE_EDIT_DNS_TOKEN>
#
# Prerequisites:
#   - SSH access to the server (via ~/.ssh/config alias)
#   - sudo on the target server
#   - Server must be running CapRover with nginx

set -euo pipefail

# ──────────────────────────────────────────────────────────────────────────────
# Parse arguments
# ──────────────────────────────────────────────────────────────────────────────

SERVER=""
DOMAIN=""
CF_TOKEN=""
EMAIL="admin@qwickapps.com"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --server)
      SERVER="$2"
      shift 2
      ;;
    --domain)
      DOMAIN="$2"
      shift 2
      ;;
    --cloudflare-token)
      CF_TOKEN="$2"
      shift 2
      ;;
    --email)
      EMAIL="$2"
      shift 2
      ;;
    *)
      echo "Unknown argument: $1"
      exit 1
      ;;
  esac
done

if [ -z "$SERVER" ] || [ -z "$DOMAIN" ] || [ -z "$CF_TOKEN" ]; then
  echo "Usage: bash setup-wildcard-ssl.sh --server <ssh-host> --domain <caprover-domain> --cloudflare-token <token>"
  exit 1
fi

WILDCARD_NAME="wildcard.$DOMAIN"

echo "=========================================="
echo "Wildcard SSL Setup"
echo "  Server:  $SERVER"
echo "  Domain:  *.$DOMAIN"
echo "  Email:   $EMAIL"
echo "=========================================="
echo ""

# ──────────────────────────────────────────────────────────────────────────────
# Step 1: Install certbot and Cloudflare DNS plugin
# ──────────────────────────────────────────────────────────────────────────────

echo "Step 1: Installing certbot and Cloudflare DNS plugin..."
ssh "$SERVER" "
  sudo apt-get update -qq
  sudo apt-get install -y -qq certbot python3-certbot-dns-cloudflare
" 2>&1 | tail -3
echo "  Done"
echo ""

# ──────────────────────────────────────────────────────────────────────────────
# Step 2: Create Cloudflare credentials file
# ──────────────────────────────────────────────────────────────────────────────

echo "Step 2: Creating Cloudflare credentials..."
ssh "$SERVER" "
  sudo mkdir -p /etc/letsencrypt
  echo 'dns_cloudflare_api_token = $CF_TOKEN' | sudo tee /etc/letsencrypt/cloudflare.ini > /dev/null
  sudo chmod 600 /etc/letsencrypt/cloudflare.ini
"
echo "  Created /etc/letsencrypt/cloudflare.ini"
echo ""

# ──────────────────────────────────────────────────────────────────────────────
# Step 3: Obtain wildcard certificate
# ──────────────────────────────────────────────────────────────────────────────

echo "Step 3: Obtaining wildcard certificate for *.$DOMAIN..."
ssh "$SERVER" "
  sudo certbot certonly \
    --dns-cloudflare \
    --dns-cloudflare-credentials /etc/letsencrypt/cloudflare.ini \
    --dns-cloudflare-propagation-seconds 30 \
    -d '*.$DOMAIN' \
    -d '$DOMAIN' \
    --email '$EMAIL' \
    --agree-tos \
    --non-interactive \
    2>&1
"
echo ""

# ──────────────────────────────────────────────────────────────────────────────
# Step 4: Copy wildcard cert to CapRover's cert directory
# ──────────────────────────────────────────────────────────────────────────────

echo "Step 4: Copying wildcard cert to CapRover cert store..."
ssh "$SERVER" "
  CERT_DIR=/captain/data/letencrypt/etc/live
  WILDCARD_DIR=\$CERT_DIR/$WILDCARD_NAME

  sudo mkdir -p \$WILDCARD_DIR
  sudo cp /etc/letsencrypt/live/$DOMAIN/fullchain.pem \$WILDCARD_DIR/
  sudo cp /etc/letsencrypt/live/$DOMAIN/privkey.pem \$WILDCARD_DIR/
  sudo cp /etc/letsencrypt/live/$DOMAIN/chain.pem \$WILDCARD_DIR/
  sudo cp /etc/letsencrypt/live/$DOMAIN/cert.pem \$WILDCARD_DIR/
"
echo "  Copied to /captain/data/letencrypt/etc/live/$WILDCARD_NAME/"
echo ""

# ──────────────────────────────────────────────────────────────────────────────
# Step 5: Replace all existing app cert directories with symlinks
# ──────────────────────────────────────────────────────────────────────────────

echo "Step 5: Replacing individual cert directories with wildcard symlinks..."
REPLACED=$(ssh "$SERVER" "
  CERT_DIR=/captain/data/letencrypt/etc/live
  count=0
  for entry in \$(sudo ls \$CERT_DIR | grep -v README | grep -v '$WILDCARD_NAME'); do
    if [ ! -L \"\$CERT_DIR/\$entry\" ]; then
      sudo rm -rf \"\$CERT_DIR/\$entry\"
      sudo ln -s $WILDCARD_NAME \"\$CERT_DIR/\$entry\"
      count=\$((count + 1))
    fi
  done
  echo \$count
")
echo "  Replaced $REPLACED cert directories with symlinks"
echo ""

# ──────────────────────────────────────────────────────────────────────────────
# Step 6: Create sync script and cron job
# ──────────────────────────────────────────────────────────────────────────────

echo "Step 6: Creating sync script and cron job..."
ssh "$SERVER" "
  sudo tee /captain/data/wildcard-ssl-sync.sh > /dev/null << 'SYNCSCRIPT'
#!/bin/bash
CERT_DIR=/captain/data/letencrypt/etc/live
WILDCARD=$WILDCARD_NAME

for entry in \$CERT_DIR/*.$DOMAIN; do
  name=\$(basename \"\$entry\")
  [ \"\$name\" = \"\$WILDCARD\" ] && continue
  if [ ! -L \"\$entry\" ]; then
    rm -rf \"\$entry\"
    ln -s \$WILDCARD \"\$entry\"
    echo \"Replaced \$name with wildcard symlink\"
  fi
done

if [ -n \"\$1\" ]; then
  target=\"\$CERT_DIR/\$1.$DOMAIN\"
  if [ ! -e \"\$target\" ]; then
    ln -s \$WILDCARD \"\$target\"
    echo \"Created wildcard symlink for \$1\"
  fi
fi
SYNCSCRIPT
  sudo chmod +x /captain/data/wildcard-ssl-sync.sh

  # Add cron job (replace existing if present)
  (sudo crontab -l 2>/dev/null | grep -v wildcard-ssl-sync; echo '*/5 * * * * /captain/data/wildcard-ssl-sync.sh >> /var/log/wildcard-ssl-sync.log 2>&1') | sudo crontab -
"
echo "  Created /captain/data/wildcard-ssl-sync.sh"
echo "  Added cron job (every 5 minutes)"
echo ""

# ──────────────────────────────────────────────────────────────────────────────
# Step 7: Create renewal hook
# ──────────────────────────────────────────────────────────────────────────────

echo "Step 7: Creating renewal hook..."
ssh "$SERVER" "
  sudo mkdir -p /etc/letsencrypt/renewal-hooks/deploy
  sudo tee /etc/letsencrypt/renewal-hooks/deploy/caprover-wildcard.sh > /dev/null << 'RENEWHOOK'
#!/bin/bash
CAPROVER_CERT=/captain/data/letencrypt/etc/live/$WILDCARD_NAME
LE_CERT=/etc/letsencrypt/live/$DOMAIN
cp \$LE_CERT/fullchain.pem \$CAPROVER_CERT/
cp \$LE_CERT/privkey.pem \$CAPROVER_CERT/
cp \$LE_CERT/chain.pem \$CAPROVER_CERT/
cp \$LE_CERT/cert.pem \$CAPROVER_CERT/
NGINX_CONTAINER=\$(docker ps --format '{{.Names}}' | grep captain-nginx)
docker exec \$NGINX_CONTAINER nginx -s reload 2>/dev/null
echo \"\$(date): Wildcard cert renewed and nginx reloaded\" >> /var/log/wildcard-ssl-sync.log
RENEWHOOK
  sudo chmod +x /etc/letsencrypt/renewal-hooks/deploy/caprover-wildcard.sh
"
echo "  Created /etc/letsencrypt/renewal-hooks/deploy/caprover-wildcard.sh"
echo ""

# ──────────────────────────────────────────────────────────────────────────────
# Step 8: Test nginx and reload
# ──────────────────────────────────────────────────────────────────────────────

echo "Step 8: Testing nginx configuration..."
NGINX_TEST=$(ssh "$SERVER" "
  NGINX_CONTAINER=\$(docker ps --format '{{.Names}}' | grep captain-nginx)
  docker exec \$NGINX_CONTAINER nginx -t 2>&1
  echo '---'
  docker exec \$NGINX_CONTAINER nginx -s reload 2>&1
")

if echo "$NGINX_TEST" | grep -q "test is successful"; then
  echo "  Nginx config valid, reloaded"
else
  echo "  WARNING: Nginx test failed:"
  echo "$NGINX_TEST"
  exit 1
fi
echo ""

# ──────────────────────────────────────────────────────────────────────────────
# Step 9: Verify
# ──────────────────────────────────────────────────────────────────────────────

echo "Step 9: Verifying wildcard cert is served..."
CERT_SUBJECT=$(ssh "$SERVER" "
  echo | openssl s_client -connect 127.0.0.1:443 -servername captain.$DOMAIN 2>/dev/null | openssl x509 -noout -subject 2>/dev/null
")
echo "  $CERT_SUBJECT"

if echo "$CERT_SUBJECT" | grep -q "\*\.$DOMAIN"; then
  echo ""
  echo "=========================================="
  echo "  Wildcard SSL setup complete!"
  echo "  *.$DOMAIN is now covered."
  echo "=========================================="
else
  echo ""
  echo "  WARNING: Wildcard cert not yet served. May need a moment for nginx to pick up changes."
fi
