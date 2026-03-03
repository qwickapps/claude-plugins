---
name: configuring-services
description: "This skill should be used when installing and configuring software on OCI VMs via SSH. Covers CapRover (Docker PaaS), PostgreSQL 16 with pgvector, and OpenClaw AI assistant. Each VM configuration is standalone. Trigger phrases: 'configure VMs', 'install services', 'set up CapRover', 'install PostgreSQL', 'install OpenClaw'."
---

# Configuring Services

SSH into each VM and install the appropriate software stack. Each section is standalone -- only execute sections that match the VM allocation.

Read `~/qwickapps-topology.yml` if it exists. The topology file lists which VMs exist and their current software. Skip configuration for VMs already marked with a `status: running` and matching software in the topology file (they were configured in a previous run).

<HARD-GATE>
Before running any commands on a VM, verify SSH access works. If SSH fails, stop and troubleshoot before proceeding.
</HARD-GATE>

## App Server -- CapRover

**Applies to:** VMs using `apps-large`, `apps-small`, or `dev-server` templates.

SSH into the apps VM and execute these steps in order. Present each block to the user before executing.

### Step 1: System Update

```bash
ssh <vm-name> "sudo apt update && sudo apt upgrade -y"
```

### Step 2: Install Docker (Official APT Repo)

Do NOT use snap. Use the official Docker APT repository for ARM.

The heredoc delimiter is single-quoted (`'DOCKER_INSTALL'`) so that `$(dpkg --print-architecture)` and `$(. /etc/os-release ...)` expand on the remote VM (ARM), not on your local machine (likely x86). Do not change to double quotes.

```bash
ssh <vm-name> 'bash -s' << 'DOCKER_INSTALL'
sudo apt-get install -y ca-certificates curl gnupg
sudo install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
sudo chmod a+r /etc/apt/keyrings/docker.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo $VERSION_CODENAME) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
sudo apt-get update
sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
sudo usermod -aG docker ubuntu
DOCKER_INSTALL
```

### Step 3: Configure UFW Firewall

```bash
ssh <vm-name> 'bash -s' << 'UFW_SETUP'
sudo ufw allow 22/tcp
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
sudo ufw allow 3000/tcp
sudo ufw allow 996/tcp
sudo ufw allow 7946/tcp
sudo ufw allow 4789/tcp
sudo ufw allow 2377/tcp
sudo ufw allow 7946/udp
sudo ufw allow 4789/udp
sudo ufw allow 2377/udp
sudo ufw --force enable
UFW_SETUP
```

### Step 4: Start CapRover

```bash
ssh <vm-name> 'docker run -d \
  --name caprover \
  --restart always \
  -p 80:80 -p 443:443 -p 3000:3000 \
  -e ACCEPTED_TERMS=true \
  -v /var/run/docker.sock:/var/run/docker.sock \
  -v /captain:/captain \
  caprover/caprover'
```

CapRover takes 1-2 minutes to initialize. Poll until ready:
```bash
ssh <vm-name> 'for i in $(seq 1 12); do
  STATUS=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:3000 2>/dev/null)
  [ "$STATUS" = "200" ] || [ "$STATUS" = "302" ] && echo "CapRover: HTTP $STATUS (ready)" && exit 0
  echo "Waiting for CapRover... (attempt $i/12)"
  sleep 10
done
echo "CapRover: not responding after 120s" && exit 1'
```

Expected: HTTP 200 or 302 within 2 minutes.

**Default CapRover password:** `captain42` (change immediately via dashboard).

### Step 5: Idle Protection Cron

```bash
ssh <vm-name> '(crontab -l 2>/dev/null; echo "0 */6 * * * dd if=/dev/urandom bs=1M count=100 | md5sum > /dev/null 2>&1") | crontab -'
```

### Verification

```bash
ssh <vm-name> "docker ps --format '{{.Names}}: {{.Status}}' && crontab -l"
```

---

## Database Server -- PostgreSQL

**Applies to:** VMs using the `db-standard` template.

### Step 1: System Update

```bash
ssh <vm-name> "sudo apt update && sudo apt upgrade -y"
```

### Step 2: Install PostgreSQL 16 from Official Repo

```bash
ssh <vm-name> 'bash -s' << 'PG_INSTALL'
sudo apt-get install -y curl ca-certificates
sudo install -d /usr/share/postgresql-common/pgdg
sudo curl -o /usr/share/postgresql-common/pgdg/apt.postgresql.org.asc --fail https://www.postgresql.org/media/keys/ACCC4CF8.asc
echo "deb [signed-by=/usr/share/postgresql-common/pgdg/apt.postgresql.org.asc] https://apt.postgresql.org/pub/repos/apt $(lsb_release -cs)-pgdg main" | sudo tee /etc/apt/sources.list.d/pgdg.list
sudo apt-get update
sudo apt-get install -y postgresql-16 postgresql-16-pgvector
PG_INSTALL
```

### Step 3: Configure PostgreSQL

Adjust configuration based on the VM's RAM allocation. Values below assume 6 GB RAM (db-standard). Scale proportionally for other allocations.

```bash
ssh <vm-name> 'bash -s' << 'PG_CONFIG'
# postgresql.conf tuning
sudo sed -i "s/#listen_addresses = 'localhost'/listen_addresses = '*'/" /etc/postgresql/16/main/postgresql.conf
sudo sed -i "s/max_connections = 100/max_connections = 100/" /etc/postgresql/16/main/postgresql.conf
sudo sed -i "s/shared_buffers = 128MB/shared_buffers = 1536MB/" /etc/postgresql/16/main/postgresql.conf
echo "effective_cache_size = 4608MB" | sudo tee -a /etc/postgresql/16/main/postgresql.conf
echo "work_mem = 16MB" | sudo tee -a /etc/postgresql/16/main/postgresql.conf

# pg_hba.conf - allow VCN access
echo "host all all 10.0.0.0/16 scram-sha-256" | sudo tee -a /etc/postgresql/16/main/pg_hba.conf
PG_CONFIG
```

For 12 GB RAM (db-standard with 2 OCPU), use:
- `shared_buffers = 3072MB`
- `effective_cache_size = 9216MB`
- `work_mem = 32MB`

### Step 4: Create Users and Databases

Generate a strong random password on the remote VM and create the application user. The password is generated and consumed entirely on the remote machine to avoid exposure in local process lists, SSH command lines, or shell history:

```bash
# Generate password on the remote VM, create user, and print the password once
ssh <vm-name> 'bash -s' << 'PG_USER'
APP_PASSWORD=$(openssl rand -base64 24 | tr -d '/+=' | head -c 32)
sudo -u postgres psql -c "CREATE USER appuser WITH PASSWORD '${APP_PASSWORD}';"
echo "=== SAVE THIS PASSWORD ==="
echo "APP_PASSWORD=${APP_PASSWORD}"
echo "=== (will not be shown again) ==="
PG_USER

ssh <vm-name> "sudo -u postgres psql -c \"CREATE DATABASE appdb OWNER appuser;\""
ssh <vm-name> "sudo -u postgres psql -c \"CREATE DATABASE clawdb OWNER appuser;\""
ssh <vm-name> "sudo -u postgres psql -c \"GRANT ALL PRIVILEGES ON DATABASE appdb TO appuser;\""
ssh <vm-name> "sudo -u postgres psql -c \"GRANT ALL PRIVILEGES ON DATABASE clawdb TO appuser;\""

# Extensions are created as postgres superuser (appuser does not need superuser)
ssh <vm-name> "sudo -u postgres psql -d appdb -c 'CREATE EXTENSION IF NOT EXISTS vector;'"
ssh <vm-name> "sudo -u postgres psql -d clawdb -c 'CREATE EXTENSION IF NOT EXISTS vector;'"
```

Save the password. Print it clearly for the user to record.

### Step 5: Restart and Enable

```bash
ssh <vm-name> "sudo systemctl enable postgresql && sudo systemctl restart postgresql"
```

### Step 6: Idle Protection Cron

```bash
ssh <vm-name> '(crontab -l 2>/dev/null; echo "0 */6 * * * dd if=/dev/urandom bs=1M count=100 | md5sum > /dev/null 2>&1") | crontab -'
```

### Verification

```bash
ssh <vm-name> "pg_isready -h localhost && sudo -u postgres psql -c '\l'"
```

Print the connection strings for the user:
```
Internal (from other VMs in VCN):
  postgresql://appuser:<password>@<private-ip>:5432/appdb
  postgresql://appuser:<password>@<private-ip>:5432/clawdb

External (SSH tunnel only):
  ssh -L 5432:<private-ip>:5432 <vm-name>
  Then connect to: postgresql://appuser:<password>@localhost:5432/appdb
```

---

## AI Assistant -- OpenClaw

**Applies to:** VMs using the `ai-assistant` template.

### Prerequisites

Before starting, confirm the user has:
- Telegram bot token (from @BotFather)
- Claude API key or subscription OAuth credentials

If not, guide them through creating a Telegram bot:
1. Open Telegram, search for @BotFather
2. Send `/newbot`, choose name and username (must end in `bot`)
3. Save the token BotFather returns

### Step 1: System Update

```bash
ssh <vm-name> "sudo apt update && sudo apt upgrade -y"
```

### Step 2: Install Docker

Same Docker installation as the app server (Step 2 from CapRover section above).

### Step 3: Clone and Set Up OpenClaw

```bash
ssh <vm-name> 'bash -s' << 'CLAW_SETUP'
# Verify the repo URL is correct before cloning. Update if the project has moved.
sudo git clone https://github.com/openclaw/openclaw.git /opt/openclaw
test -d /opt/openclaw && echo "Clone: OK" || { echo "Clone: FAILED -- verify the repo URL"; exit 1; }
cd /opt/openclaw
sudo bash docker-setup.sh
CLAW_SETUP
```

During the setup, the user may need to provide:
- AI Provider selection (Anthropic/Claude recommended)
- API key or OAuth token
- Telegram bot token

### Step 4: Start OpenClaw

```bash
ssh <vm-name> "cd /opt/openclaw && sudo docker compose up -d"
```

### Step 5: Idle Protection Cron

```bash
ssh <vm-name> '(crontab -l 2>/dev/null; echo "0 */6 * * * dd if=/dev/urandom bs=1M count=100 | md5sum > /dev/null 2>&1") | crontab -'
```

### Verification

```bash
ssh <vm-name> "cd /opt/openclaw && docker compose ps && docker compose logs --tail 20"
```

Check that all containers are running and no error logs appear.

---

## Co-Located OpenClaw (On Apps VM)

If the allocation has OpenClaw co-located with CapRover (no dedicated AI VM):

```bash
ssh <apps-vm-name> 'bash -s' << 'CLAW_COLOC'
# Verify the repo URL is correct before cloning. Update if the project has moved.
sudo git clone https://github.com/openclaw/openclaw.git /opt/openclaw
test -d /opt/openclaw && echo "Clone: OK" || { echo "Clone: FAILED -- verify the repo URL"; exit 1; }
cd /opt/openclaw
sudo bash docker-setup.sh
sudo docker compose up -d
CLAW_COLOC
```

Note: This shares resources with CapRover. Monitor resource usage and consider a dedicated VM if OpenClaw impacts app performance.

---

## Dev Server -- CapRover (Dev/Staging)

**Applies to:** VMs using the `dev-server` template.

The dev server uses the same CapRover setup as the app server. Follow all steps in the "App Server -- CapRover" section above, substituting the dev VM name (e.g., `oci-dev`) for `<vm-name>`.

The dev CapRover instance operates independently from production. Deploy dev/staging builds here to isolate CPU spikes from frequent builds. Production apps remain on the apps VM.

---

## Post-Configuration Summary

After all VMs are configured, print only sections matching the allocation:

```
=== Service Configuration Summary ===

CapRover - Production (<apps-vm>):
  Dashboard: http://<public-ip>:3000
  Default password: captain42 (CHANGE IMMEDIATELY)
  Status: [docker ps output]

CapRover - Dev/Staging (<dev-vm>):
  Dashboard: http://<public-ip>:3000
  Default password: captain42 (CHANGE IMMEDIATELY)
  Status: [docker ps output]

PostgreSQL (<db-vm>):
  Internal connection: postgresql://appuser:<pwd>@<private-ip>:5432/appdb
  SSH tunnel: ssh -L 5432:<private-ip>:5432 <db-vm>
  Databases: appdb, clawdb
  Status: [pg_isready output]

OpenClaw (<claw-vm>):
  Status: [docker compose ps output]
  Telegram bot: @<bot-username>

Idle Protection:
  All VMs: cron job running every 6 hours

Next Steps:
  1. Set up DNS records (load setting-up-dns skill)
  2. Change CapRover default passwords (both prod and dev)
  3. Deploy your first app via CapRover dashboard
```
