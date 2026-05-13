---
name: wildcard-ssl
description: >
  This skill should be used when setting up or troubleshooting wildcard SSL certificates
  on CapRover servers, when adding a new CapRover server to the infrastructure, when
  debugging SSL certificate issues or Let's Encrypt rate limits, or when understanding
  how SSL works across the deployment infrastructure. Trigger phrases: "wildcard SSL",
  "SSL certificate", "Let's Encrypt", "rate limit", "certificate error", "HTTPS setup",
  "set up SSL on CapRover", "cert expired", "SSL renewal".
---

# Wildcard SSL for CapRover

All three CapRover servers use Let's Encrypt wildcard certificates via DNS-01 challenge with Cloudflare. This eliminates per-app certificate requests and avoids Let's Encrypt rate limits.

---

## Architecture

Each CapRover server has a single wildcard certificate that covers all apps on its domain:

| Server | Wildcard Cert | Covers |
|--------|--------------|--------|
| oci-dev | `*.dev.qwickforge.com` | All dev apps |
| oci-main | `*.app.qwickforge.com` | All prod and uat apps |
| oci-gateway | `*.route.qwickforge.com` | All QwickWay gateway apps |

CapRover expects individual cert directories per app at `/captain/data/letencrypt/etc/live/<app>.<domain>/`. The wildcard system creates relative symlinks from each app's cert directory to the wildcard cert directory:

```
/captain/data/letencrypt/etc/live/
  wildcard.dev.qwickforge.com/     <-- real directory with wildcard cert files
  faabzi.dev.qwickforge.com        -> wildcard.dev.qwickforge.com  (symlink)
  work-macha.dev.qwickforge.com    -> wildcard.dev.qwickforge.com  (symlink)
  captain.dev.qwickforge.com       -> wildcard.dev.qwickforge.com  (symlink)
```

**Important:** Symlinks must be **relative** (just the directory name, not absolute paths) because nginx runs inside a Docker container with different mount paths than the host.

---

## Components on Each Server

### 1. Wildcard Certificate

Obtained via certbot with the Cloudflare DNS plugin:

```bash
sudo certbot certonly \
  --dns-cloudflare \
  --dns-cloudflare-credentials /etc/letsencrypt/cloudflare.ini \
  --dns-cloudflare-propagation-seconds 30 \
  -d '*.DOMAIN' \
  -d 'DOMAIN' \
  --email admin@qwickapps.com \
  --agree-tos \
  --non-interactive
```

The cert is stored at `/etc/letsencrypt/live/DOMAIN/` and copied to CapRover's cert directory at `/captain/data/letencrypt/etc/live/wildcard.DOMAIN/`.

### 2. Cloudflare Credentials

Stored at `/etc/letsencrypt/cloudflare.ini` with mode `600`:

```ini
dns_cloudflare_api_token = <CLOUDFLARE_EDIT_DNS_TOKEN>
```

The token is the `CLOUDFLARE_EDIT_DNS_TOKEN` from `environments.yml` (infrastructure.cloudflare.secrets section).

### 3. Sync Script

Located at `/captain/data/wildcard-ssl-sync.sh`. Runs every 5 minutes via cron. Replaces any real cert directory (created by CapRover's individual cert requests) with a symlink to the wildcard cert.

The script also accepts an app name argument to pre-create a symlink:

```bash
/captain/data/wildcard-ssl-sync.sh myapp
```

### 4. Renewal Hook

Located at `/etc/letsencrypt/renewal-hooks/deploy/caprover-wildcard.sh`. When certbot auto-renews the wildcard cert, this hook copies the new cert to CapRover's cert directory and reloads nginx.

### 5. Auto-Renewal

Certbot's systemd timer (`certbot.timer`) runs twice daily and handles renewal automatically. The renewal hook ensures CapRover picks up the new cert.

---

## How New Apps Get SSL

When a new CapRover app is created and `hasDefaultSubDomainSsl` is set to `true` in its configuration:

1. The deployment script sets `hasDefaultSubDomainSsl: true` in the app definition (no API call to `enablebasedomainssl` needed).
2. CapRover generates nginx config pointing to `/letencrypt/etc/live/<app>.DOMAIN/fullchain.pem`.
3. Within 5 minutes, the cron job creates a symlink from `<app>.DOMAIN` to `wildcard.DOMAIN`.
4. Nginx serves the wildcard cert for the new app.

If immediate SSL is needed (before the 5-minute cron), run the sync script manually via SSH:

```bash
ssh <server> "sudo /captain/data/wildcard-ssl-sync.sh <app-name>"
```

---

## Custom Domain SSL

Wildcard certs only cover `*.<server-domain>` subdomains. Custom domains (e.g., `faabzi.com`, `dev.faabzi.com`) on the QwickWay gateway still use individual Let's Encrypt certs via the `enablecustomdomainssl` API call. This is handled by the `setup-qwickway-route.sh` script and is unaffected by the wildcard setup.

---

## Setting Up Wildcard SSL on a New Server

Use the `setup-wildcard-ssl.sh` script from `${CLAUDE_PLUGIN_ROOT}/scripts/`:

```bash
bash setup-wildcard-ssl.sh \
  --server <ssh-host> \
  --domain <caprover-root-domain> \
  --cloudflare-token <token>
```

The script:
1. Installs certbot and the Cloudflare DNS plugin
2. Creates the Cloudflare credentials file
3. Obtains the wildcard certificate
4. Copies it to CapRover's cert directory
5. Replaces all existing app cert directories with symlinks
6. Creates the sync script and cron job
7. Creates the renewal hook
8. Tests and reloads nginx

---

## Troubleshooting

### Certificate shows old CN (not wildcard)

The symlink may not exist yet. Check and fix:

```bash
ssh <server> "sudo ls -la /captain/data/letencrypt/etc/live/<app>.<domain>"
# If it's a real directory (not symlink), run:
ssh <server> "sudo /captain/data/wildcard-ssl-sync.sh"
```

### Nginx fails to start after symlink creation

Symlinks must be relative. Verify:

```bash
# Correct (relative):
faabzi.dev.qwickforge.com -> wildcard.dev.qwickforge.com

# Wrong (absolute - will fail in nginx container):
faabzi.dev.qwickforge.com -> /captain/data/letencrypt/etc/live/wildcard.dev.qwickforge.com
```

Fix absolute symlinks:

```bash
ssh <server> "
  CERT_DIR=/captain/data/letencrypt/etc/live
  for link in \$(sudo find \$CERT_DIR -maxdepth 1 -type l); do
    target=\$(readlink \$link)
    if [[ \$target == /* ]]; then
      name=\$(basename \$link)
      sudo rm \$link
      sudo ln -s wildcard.<domain> \$CERT_DIR/\$name
    fi
  done
"
```

### Wildcard cert expired

Check renewal status:

```bash
ssh <server> "sudo certbot certificates"
ssh <server> "sudo systemctl status certbot.timer"
```

Force renewal:

```bash
ssh <server> "sudo certbot renew --force-renewal"
```

The renewal hook automatically copies the new cert to CapRover and reloads nginx.

### Rate limit errors

With the wildcard cert, per-app rate limits are no longer an issue. If you see rate limit errors, an old workflow or script may still be calling `enablebasedomainssl`. Update the workflow to use `--enable-ssl false` and set `hasDefaultSubDomainSsl: true` directly in the app definition.

---

## Server Reference

| Server | SSH Host | Domain | Cert Path |
|--------|----------|--------|-----------|
| oci-dev | `oci-dev` | `dev.qwickforge.com` | `/etc/letsencrypt/live/dev.qwickforge.com/` |
| oci-main | `oci-main` | `app.qwickforge.com` | `/etc/letsencrypt/live/app.qwickforge.com/` |
| oci-gateway | `oci-gateway` | `route.qwickforge.com` | `/etc/letsencrypt/live/route.qwickforge.com/` |

Cloudflare credentials: `/etc/letsencrypt/cloudflare.ini` (same token on all servers)

Sync script: `/captain/data/wildcard-ssl-sync.sh` (server-specific wildcard name)

Renewal hook: `/etc/letsencrypt/renewal-hooks/deploy/caprover-wildcard.sh`

Cron: `*/5 * * * * /captain/data/wildcard-ssl-sync.sh`
