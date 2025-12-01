# Pi-hole Configuration & Sync Guide

## Overview

This setup includes:
- **Two Pi-hole v6 instances** (Primary & Secondary) for high availability
- **Automatic configuration sync** between instances
- **Pre-configured blocklists**: High-quality, curated lists for strong ad/malware/tracker filtering
- **Streaming whitelist**: Disney+, Netflix, and other services for compatibility
- **Profile-based configuration**: Choose standard, family, or paranoid blocking levels

## Default Blocklists

Out of the box, Pi-hole is configured with a curated set of high-quality, well-maintained blocklists:

### Core Lists (All Profiles)

| List | URL | Domains | Description |
|------|-----|---------|-------------|
| **Hagezi Pro++** | https://cdn.jsdelivr.net/gh/hagezi/dns-blocklists@latest/wildcard/pro.plus.txt | ~3M | Comprehensive protection: ads, tracking, malware, phishing |
| **OISD Big** | https://big.oisd.nl/domainswild | ~1.9M | Balanced blocking with low false positives |
| **Hagezi Threat** | https://cdn.jsdelivr.net/gh/hagezi/dns-blocklists@latest/wildcard/threat-intelligence.txt | ~500K | Malware, phishing, and threat intelligence |

### Additional Lists by Profile

| Profile | Additional Lists | Total Domains |
|---------|------------------|---------------|
| **Standard** | Core lists only | ~4-5M |
| **Family** | + Hagezi Multi | ~5-6M |
| **Paranoid** | + Hagezi Multi + Hagezi Ultimate | ~7-8M |

### Blocklist Profile Details

#### Standard Profile (Default)
Best for: General home/office use
- Blocks ads, trackers, and malware
- Low false positive rate
- Minimal website breakage

#### Family Profile
Best for: Families with children
- Everything in Standard
- Enhanced protection for family-safe browsing
- Blocks additional suspicious domains

#### Paranoid Profile
Best for: Privacy-focused users
- Maximum blocking coverage
- May cause some website breakage
- Recommended for advanced users who can troubleshoot

### Optional Reference List

Not installed by default, but available for manual addition:
- **StevenBlack Unified**: https://raw.githubusercontent.com/StevenBlack/hosts/master/hosts

## Initial Setup

### 1. Deploy the Stack

```bash
cd /opt/rpi-ha-dns-stack/stacks/dns

# Ensure network exists
sudo docker network create \
  -d macvlan \
  --subnet=192.168.8.0/24 \
  --gateway=192.168.8.1 \
  -o parent=eth0 \
  dns_net

# Build and start services
sudo docker compose build keepalived
sudo docker compose up -d
```

### 2. Configure Pi-hole (First Time Only)

Wait about 60 seconds for containers to fully start, then run:

```bash
cd /opt/rpi-ha-dns-stack/stacks/dns

# Use default standard profile
sudo bash setup-pihole.sh

# Or specify a profile
PIHOLE_BLOCKLIST_PROFILE=family sudo bash setup-pihole.sh
PIHOLE_BLOCKLIST_PROFILE=paranoid sudo bash setup-pihole.sh
```

This script will:
- ✅ Add curated blocklists based on selected profile
- ✅ Whitelist streaming service domains (Disney+, Netflix, etc.)
- ✅ Update gravity database
- ✅ Configure both primary and secondary instances
- ✅ Skip already-configured items (idempotent)

### 3. Verify Installation

```bash
# Check Pi-hole status
docker exec pihole_primary pihole status

# View blocklist count
docker exec pihole_primary pihole -g -l

# Test DNS resolution
dig @192.168.8.251 google.com +short

# Test ad blocking
dig @192.168.8.251 ads.google.com +short  # Should return 0.0.0.0 or NXDOMAIN

# View gravity statistics
docker exec pihole_primary pihole -c -e
```

## Configuration Sync

### Automatic Sync (Recommended)

The `pihole-sync` container runs automatically and syncs every 5 minutes:

```bash
# Check sync logs
sudo docker logs pihole-sync -f

# Restart sync service
sudo docker compose restart pihole-sync
```

### Manual Sync

To manually trigger a sync:

```bash
cd /opt/rpi-ha-dns-stack/stacks/dns
sudo bash pihole-sync.sh --once
```

### What Gets Synced

- ✅ Gravity database (blocklists, groups, clients)
- ✅ Custom DNS records
- ✅ Adlist configuration
- ✅ Whitelist/Blacklist
- ✅ Regex filters

## Blocklists Reference

### Included Blocklists

| List | Domains | Profile | Description |
|------|---------|---------|-------------|
| **Hagezi Pro++** | ~3M | All | Comprehensive protection: ads, tracking, malware, phishing |
| **OISD Big** | ~1.9M | All | Balanced blocking with very low false positives |
| **Hagezi Threat Intelligence** | ~500K | All | Malware, phishing, C&C servers, threat intel feeds |
| **Hagezi Multi** | ~1M | Family+ | Multi-purpose blocklist with family-safe filtering |
| **Hagezi Ultimate** | ~2M | Paranoid | Maximum blocking coverage |

### Trade-offs by Profile

| Metric | Standard | Family | Paranoid |
|--------|----------|--------|----------|
| **Total Domains** | ~4-5M | ~5-6M | ~7-8M |
| **Memory Usage** | ~200MB | ~250MB | ~350MB |
| **Gravity Update Time** | ~2 min | ~3 min | ~4 min |
| **False Positives** | Very Low | Low | Moderate |
| **Website Breakage** | Rare | Occasional | Possible |

### Performance Impact

- **Query Response Time**: < 50ms (all profiles)
- **CPU Usage**: < 5% (all profiles)
- **Gravity Update**: Runs daily at 3 AM

## Whitelisted Domains

### Streaming Services (Pre-configured)

**Disney+**:
- `disneyplus.com`, `disney-plus.net`, `disneystreaming.com`
- `bamgrid.com`, `dssott.com`, `disney.com`, `go.com`

**Netflix**:
- `netflix.com`, `nflxvideo.net`, `nflximg.net`, `nflxext.com`

**Amazon Prime Video**:
- `amazon.com`, `amazonvideo.com`, `aiv-cdn.net`, `aiv-delivery.net`

**Other Services**:
- Hulu, HBO Max, Apple TV+, Spotify, YouTube (basic functionality)

### Additional Domains to Whitelist (Optional)

If you experience issues with specific services, consider whitelisting:

```bash
# Plex
docker exec pihole_primary pihole -w plex.tv plex.direct

# Roku
docker exec pihole_primary pihole -w roku.com

# Twitch
docker exec pihole_primary pihole -w twitch.tv twitchcdn.net

# Gaming consoles
docker exec pihole_primary pihole -w xbox.com xboxlive.com playstation.com
```

## Managing Pi-hole

### Access Web Interface

- **Primary**: http://192.168.8.251/admin
- **Secondary**: http://192.168.8.252/admin
- **VIP (Failover)**: http://192.168.8.255/admin

### Change Blocklist Profile

To switch profiles after initial setup:

```bash
# Re-run setup with desired profile
PIHOLE_BLOCKLIST_PROFILE=family sudo bash setup-pihole.sh
```

The script is idempotent - it will only add new blocklists without duplicating existing ones.

### Add More Blocklists

1. Access Pi-hole web interface
2. Go to **Adlists**
3. Add blocklist URL
4. Run `pihole updateGravity`
5. Sync will automatically propagate to secondary

### Add to Whitelist

```bash
# Via CLI
sudo docker exec pihole_primary pihole -w example.com

# Or via Web UI: Whitelist → Add domain
```

The sync service will copy changes to the secondary within 5 minutes.

### Add to Blacklist

```bash
# Via CLI
sudo docker exec pihole_primary pihole -b badsite.com

# Or via Web UI: Blacklist → Add domain
```

## Customization via Environment Variables

Set these in your `.env` file before running setup:

```bash
# Blocklist profile (standard, family, or paranoid)
PIHOLE_BLOCKLIST_PROFILE=standard
```

Or override at runtime:

```bash
PIHOLE_BLOCKLIST_PROFILE=paranoid bash setup-pihole.sh
```

## Troubleshooting

### Check Container Status

```bash
sudo docker compose ps
```

All containers should show "Up (healthy)".

### Check Sync Status

```bash
sudo docker logs pihole-sync --tail 50
```

### Manual Gravity Update

```bash
# Update primary
sudo docker exec pihole_primary pihole updateGravity

# Sync to secondary
sudo bash pihole-sync.sh --once
```

### Verify Blocklist Count

```bash
# Check how many domains are blocked
sudo docker exec pihole_primary pihole -q -adlist
```

## Configuration Sync vs Gravity Sync

**Why not Gravity Sync?**
- Gravity Sync doesn't support Pi-hole v6
- Our solution works with v6 and is simpler
- Direct database synchronization is more reliable
- No SSH keys or complex setup required

**How It Works:**
1. Sync container runs on the same host as Pi-hole
2. Uses Docker socket to access both containers
3. Copies configuration files directly
4. Triggers DNS reload on secondary
5. Runs automatically every 5 minutes (configurable)

## Performance

With ~5 million blocked domains:
- Query response time: < 50ms
- Memory usage per instance: ~200MB
- CPU usage: < 5%
- Sync duration: ~10 seconds

## Best Practices

1. **Make changes on Primary**: Always configure via primary Pi-hole
2. **Wait for sync**: Changes propagate within 5 minutes
3. **Monitor sync logs**: Check logs occasionally for errors
4. **Backup regularly**: Backup `/opt/rpi-ha-dns-stack/stacks/dns/pihole1`
5. **Test failover**: Verify secondary works by stopping primary

## Security Notes

- Pi-hole admin password set via `.env` file
- Sync uses read-only Docker socket mount
- No network exposure for sync container
- All communication via local Docker network

## Additional Resources

- [Pi-hole Documentation](https://docs.pi-hole.net/)
- [Hagezi Blocklists](https://github.com/hagezi/dns-blocklists)
- [OISD Blocklists](https://oisd.nl/)
