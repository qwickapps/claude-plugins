---
name: provisioning-oci
description: "This skill should be used when creating Oracle Cloud VMs via the OCI CLI. Handles VCN creation, instance launch, reserved IPs, SSH config, and retry logic for capacity errors. Each step requires user confirmation before execution. Trigger phrases: 'provision VMs', 'create OCI instances', 'launch cloud VMs', 'set up Oracle Cloud'."
---

# Provisioning OCI Infrastructure

Step-by-step OCI provisioning via CLI. Every command that creates or modifies resources requires user confirmation before execution.

<HARD-GATE>
NEVER execute OCI CLI commands that create, modify, or delete resources without explicit user confirmation. Present the command, explain what it does, and wait for approval.
</HARD-GATE>

## Prerequisites

Before starting, verify all prerequisites. If any fail, stop and guide the user to fix them.

```bash
# 1. OCI CLI installed and configured
test -f ~/.oci/config && echo "OCI config: OK" || echo "OCI config: MISSING"

# 2. SSH key exists
test -f ~/.ssh/id_oci.pub && echo "SSH key: OK" || echo "SSH key: MISSING"

# 3. Environment file exists and has required vars
# Source the env file and check for OCI_TENANCY_OCID, OCI_REGION
```

If OCI CLI is not configured, guide the user:
1. Install: `brew install oci-cli` (macOS) or official installer (Linux)
2. Configure: `oci setup config`
3. Upload API key to OCI Console
4. Verify: `oci iam region list --output table`

If SSH key is missing: `ssh-keygen -t ed25519 -f ~/.ssh/id_oci -N "" -C "oci-vms"`

## Capacity Check

Run the capacity checker before attempting to create instances:

```bash
bash ${CLAUDE_PLUGIN_ROOT}/scripts/oci-check-capacity.sh
```

If ARM capacity is not available, advise:
1. Upgrade to Pay-As-You-Go (see `${CLAUDE_PLUGIN_ROOT}/references/oci-free-tier-limits.md`)
2. Retry later (capacity fluctuates throughout the day)
3. This skill includes automatic retry logic

## Step 1: Network Setup (VCN)

Create the Virtual Cloud Network if one does not already exist.

**Check for existing VCN:**
```bash
oci network vcn list \
  --compartment-id "$OCI_COMPARTMENT_OCID" \
  --query 'data[*].{name:"display-name", id:id, cidr:"cidr-block"}' \
  --output table
```

If no VCN exists, create one. Present each command to the user before execution:

**1a. Create VCN:**
```bash
oci network vcn create \
  --compartment-id "$OCI_COMPARTMENT_OCID" \
  --cidr-block "10.0.0.0/16" \
  --display-name "free-tier-vcn" \
  --dns-label "freetier" \
  --wait-for-state AVAILABLE
```

**1b. Create Internet Gateway:**
```bash
oci network internet-gateway create \
  --compartment-id "$OCI_COMPARTMENT_OCID" \
  --vcn-id "$VCN_OCID" \
  --display-name "free-tier-igw" \
  --is-enabled true \
  --wait-for-state AVAILABLE
```

**1c. Create Route Table:**
```bash
oci network route-table create \
  --compartment-id "$OCI_COMPARTMENT_OCID" \
  --vcn-id "$VCN_OCID" \
  --display-name "free-tier-rt" \
  --route-rules '[{"destination":"0.0.0.0/0","destinationType":"CIDR_BLOCK","networkEntityId":"'"$IGW_OCID"'"}]' \
  --wait-for-state AVAILABLE
```

**1d. Create Security List:**

The security list rules depend on which VMs are being created. Refer to `${CLAUDE_PLUGIN_ROOT}/references/vm-templates.md` for per-template port requirements.

Common ingress rules (combine based on VM templates in the allocation):
- TCP 22 from 0.0.0.0/0 (SSH -- all VMs)
- TCP 80, 443 from 0.0.0.0/0 (HTTP/HTTPS -- apps, ai-assistant)
- TCP 3000 from 0.0.0.0/0 (CapRover -- apps only)
- TCP 996, 7946, 4789, 2377 from 0.0.0.0/0 (Docker Swarm -- apps only)
- UDP 7946, 4789, 2377 from 0.0.0.0/0 (Docker Swarm -- apps only)
- TCP 5432 from 10.0.0.0/16 (PostgreSQL -- db only, VCN internal)

Full Stack split example (all ports for apps + db + ai-assistant):

```bash
oci network security-list create \
  --compartment-id "$OCI_COMPARTMENT_OCID" \
  --vcn-id "$VCN_OCID" \
  --display-name "free-tier-sl" \
  --ingress-security-rules '[
    {"source":"0.0.0.0/0","protocol":"6","tcpOptions":{"destinationPortRange":{"min":22,"max":22}}},
    {"source":"0.0.0.0/0","protocol":"6","tcpOptions":{"destinationPortRange":{"min":80,"max":80}}},
    {"source":"0.0.0.0/0","protocol":"6","tcpOptions":{"destinationPortRange":{"min":443,"max":443}}},
    {"source":"0.0.0.0/0","protocol":"6","tcpOptions":{"destinationPortRange":{"min":3000,"max":3000}}},
    {"source":"0.0.0.0/0","protocol":"6","tcpOptions":{"destinationPortRange":{"min":996,"max":996}}},
    {"source":"0.0.0.0/0","protocol":"6","tcpOptions":{"destinationPortRange":{"min":7946,"max":7946}}},
    {"source":"0.0.0.0/0","protocol":"6","tcpOptions":{"destinationPortRange":{"min":4789,"max":4789}}},
    {"source":"0.0.0.0/0","protocol":"6","tcpOptions":{"destinationPortRange":{"min":2377,"max":2377}}},
    {"source":"0.0.0.0/0","protocol":"17","udpOptions":{"destinationPortRange":{"min":7946,"max":7946}}},
    {"source":"0.0.0.0/0","protocol":"17","udpOptions":{"destinationPortRange":{"min":4789,"max":4789}}},
    {"source":"0.0.0.0/0","protocol":"17","udpOptions":{"destinationPortRange":{"min":2377,"max":2377}}},
    {"source":"10.0.0.0/16","protocol":"6","tcpOptions":{"destinationPortRange":{"min":5432,"max":5432}}}
  ]' \
  --egress-security-rules '[{"destination":"0.0.0.0/0","protocol":"all"}]' \
  --wait-for-state AVAILABLE
```

For other splits, remove rules for services not in the allocation (e.g., drop port 5432 if no db VM, drop ports 3000/996/7946/4789/2377 if no CapRover).

**1e. Create Public Subnet:**
```bash
oci network subnet create \
  --compartment-id "$OCI_COMPARTMENT_OCID" \
  --vcn-id "$VCN_OCID" \
  --cidr-block "10.0.0.0/24" \
  --display-name "free-tier-public" \
  --dns-label "public" \
  --route-table-id "$RT_OCID" \
  --security-list-ids '["'"$SL_OCID"'"]' \
  --wait-for-state AVAILABLE
```

## Step 2: Create Each VM

For each VM in the approved allocation, execute the following sequence.

**2a. Find Ubuntu 22.04 ARM Image:**
```bash
oci compute image list \
  --compartment-id "$OCI_COMPARTMENT_OCID" \
  --shape "VM.Standard.A1.Flex" \
  --operating-system "Canonical Ubuntu" \
  --operating-system-version "22.04" \
  --sort-by TIMECREATED \
  --sort-order DESC \
  --limit 1 \
  --query 'data[0].id' \
  --raw-output
```

**2b. Get Availability Domain:**
```bash
oci iam availability-domain list \
  --compartment-id "$OCI_COMPARTMENT_OCID" \
  --query 'data[0].name' \
  --raw-output
```

**2c. Launch Instance:**
```bash
oci compute instance launch \
  --compartment-id "$OCI_COMPARTMENT_OCID" \
  --availability-domain "$AD_NAME" \
  --shape "VM.Standard.A1.Flex" \
  --shape-config '{"ocpus": <OCPUS>, "memoryInGBs": <RAM>}' \
  --image-id "$IMAGE_OCID" \
  --subnet-id "$SUBNET_OCID" \
  --display-name "<vm-name>" \
  --assign-public-ip true \
  --boot-volume-size-in-gbs <BOOT_VOL_GB> \
  --ssh-authorized-keys-file "$OCI_SSH_PUBLIC_KEY_PATH" \
  --wait-for-state RUNNING
```

**Retry logic for "Out of capacity":**

If the launch fails with `Out of host capacity`, retry automatically:
- Interval: 60 seconds
- Max duration: 30 minutes
- Print status each attempt: "Attempt N/30: Retrying in 60s..."
- Try each availability domain in the region before cycling

Present the retry plan to the user and get confirmation before starting retries.

**2d. Get Public IP:**
```bash
oci compute instance list-vnics \
  --instance-id "$INSTANCE_OCID" \
  --query 'data[0]."public-ip"' \
  --raw-output
```

**2e. Create Reserved IP (if needed):**
```bash
# Get the VNIC OCID and private IP OCID
VNIC_OCID=$(oci compute instance list-vnics --instance-id "$INSTANCE_OCID" --query 'data[0].id' --raw-output)
PRIVATE_IP_OCID=$(oci network private-ip list --vnic-id "$VNIC_OCID" --query 'data[0].id' --raw-output)

# Create reserved public IP
oci network public-ip create \
  --compartment-id "$OCI_COMPARTMENT_OCID" \
  --lifetime RESERVED \
  --display-name "<vm-name>-ip" \
  --private-ip-id "$PRIVATE_IP_OCID" \
  --wait-for-state AVAILABLE
```

Note: Free tier allows 2-3 reserved IPs. If exhausted, use ephemeral IPs for lower-priority VMs.

**2f. Add SSH Config Entry:**

Append to `~/.ssh/config`:
```
Host <vm-name>
    HostName <public-ip>
    User ubuntu
    IdentityFile ~/.ssh/id_oci
    StrictHostKeyChecking accept-new
```

**2g. Verify SSH Access:**
```bash
ssh -o ConnectTimeout=10 <vm-name> "echo SSH connection successful"
```

Wait up to 2 minutes for the VM to boot before declaring SSH failure.

## Step 3: Print Summary

After all VMs are created, print a summary:

```
=== OCI Infrastructure Summary ===

VMs Created:
  <vm-name>: <public-ip> (<ocpus> OCPU, <ram> GB RAM)
    OCID: <instance-ocid>
    SSH: ssh <vm-name>

Network:
  VCN: <vcn-ocid>
  Subnet: <subnet-ocid>
  Security List: <sl-ocid>

Resource Usage:
  OCPUs: X/4 used
  RAM: Y/24 GB used
  Storage: Z/200 GB used

Next Steps:
  1. Configure services on each VM (load configuring-services skill)
  2. Set up DNS records (load setting-up-dns skill)
```

## Safety Notes

- All OCI CLI commands that create resources use `--wait-for-state` to block until the operation completes
- Never delete or modify existing resources without explicit user approval
- If a VCN already exists, reuse it rather than creating a new one
- Store all OCIDs for later reference (print them in the summary)
