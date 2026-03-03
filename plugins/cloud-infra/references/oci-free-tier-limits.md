# OCI Free Tier Limits

Static reference for Oracle Cloud Infrastructure Always Free resources (ARM Ampere A1).

## Compute

| Resource | Limit | Notes |
|----------|-------|-------|
| ARM OCPUs | 4 total | VM.Standard.A1.Flex shape |
| ARM RAM | 24 GB total | Up to 6 GB per OCPU |
| Instances | Up to 4 | Can split OCPUs across 1-4 VMs |
| Boot volumes | 200 GB total | Shared across all instances |
| Shape | VM.Standard.A1.Flex | Ampere A1, aarch64/ARM |
| OS | Ubuntu 22.04 recommended | Canonical image, ARM build |

## Networking

| Resource | Limit | Notes |
|----------|-------|-------|
| VCNs | 2 | Virtual Cloud Networks |
| Public subnets | Per VCN | At least 1 needed |
| Reserved public IPs | 2-3 | Use ephemeral if exhausted |
| Flexible load balancer | 1 | 10 Mbps |
| Network load balancer | 1 | |
| Outbound data | 10 TB/month | Rarely a constraint |

## Storage

| Resource | Limit | Notes |
|----------|-------|-------|
| Block volume | 200 GB total | Shared with boot volumes |
| Object storage | 20 GB | For backups |
| Object storage requests | 50K/month | GET, PUT, etc. |

## Idle Reclamation Policy

Oracle reclaims free-tier instances idle for 7 consecutive days. An instance is considered idle when ALL of these are true over the 7-day period:

- CPU utilization < 20%
- Network utilization < 20%
- Memory utilization < 20%

**Mitigation:** Install a cron job to generate periodic CPU activity:
```bash
echo "0 */6 * * * dd if=/dev/urandom bs=1M count=100 | md5sum > /dev/null 2>&1" | crontab -
```

## Home Region

- Home region is **permanent** and cannot be changed after account creation.
- All free-tier resources must be created in the home region.
- ARM capacity varies by region and time of day.

**Recommended regions** (historically better ARM capacity):
- `us-ashburn-1` (US East)
- `uk-london-1` (UK South)
- `eu-frankfurt-1` (Germany Central)
- `ap-sydney-1` (Australia East)
- `sa-saopaulo-1` (Brazil East)
- `me-jeddah-1` (Saudi Arabia West)

**Avoid** (consistently oversubscribed):
- `us-sanjose-1` (San Jose)
- `ap-singapore-1` (Singapore)
- `ap-tokyo-1` (Tokyo)
- `ap-mumbai-1` (Mumbai)

## Pay-As-You-Go Upgrade

Upgrading to PAYG does NOT incur costs for free-tier resources. Benefits:
- Access to a larger ARM capacity pool (fewer "Out of capacity" errors)
- Resources remain free as long as usage stays within limits
- Temporary $100 hold on credit card (refunded in 1-2 days)
