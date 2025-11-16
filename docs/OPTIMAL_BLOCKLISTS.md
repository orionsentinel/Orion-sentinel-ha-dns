# Optimal Pi-hole Blocklist Setup Guide

## Overview

This guide provides **tested, optimal blocklist configurations** for Pi-hole v6. These recommendations balance effective blocking with minimal false positives.

## Quick Recommendation

**For most users, use the "Balanced" preset:**
- ~1-2 million domains blocked
- Minimal false positives
- Good performance
- Regular updates

## Blocklist Presets

### 1. Light (Recommended for Beginners)

**Best for:** New users, minimal risk of breakage, fast performance

| Blocklist | Domains | Update Frequency | Description |
|-----------|---------|------------------|-------------|
| [OISD Basic](https://oisd.nl/downloads) | ~600K | Daily | Community-curated, well-maintained |
| [1Hosts Lite](https://o0.pages.dev/Lite/adblock.txt) | ~200K | Daily | Ads, tracking, malware |

**Total:** ~800K domains  
**False Positives:** Very rare  
**Performance:** Excellent

**Setup:**
```bash
# Add via Pi-hole admin panel > Adlists:
https://hosts.oisd.nl/basic/
https://o0.pages.dev/Lite/adblock.txt
```

---

### 2. Balanced (Recommended for Most Users) ⭐

**Best for:** Home networks, families, good balance

| Blocklist | Domains | Update Frequency | Description |
|-----------|---------|------------------|-------------|
| [OISD Full](https://oisd.nl/) | ~1.1M | Daily | Comprehensive, actively maintained |
| [Hagezi Pro](https://github.com/hagezi/dns-blocklists) | ~800K | Daily | Ads, tracking, malware, scams |
| [Developer Dan Ads & Tracking](https://www.github.developerdan.com/hosts/) | ~100K | Weekly | Clean, well-tested |

**Total:** ~2 million domains  
**False Positives:** Rare, easily whitelisted  
**Performance:** Good

**Setup:**
```bash
# Add via Pi-hole admin panel > Adlists:
https://hosts.oisd.nl/
https://cdn.jsdelivr.net/gh/hagezi/dns-blocklists@latest/wildcard/pro.txt
https://www.github.developerdan.com/hosts/lists/ads-and-tracking-extended.txt
```

---

### 3. Aggressive (Advanced Users)

**Best for:** Maximum blocking, tech-savvy users who can troubleshoot

| Blocklist | Domains | Update Frequency | Description |
|-----------|---------|------------------|-------------|
| [Hagezi Pro++](https://github.com/hagezi/dns-blocklists) | ~1.5M | Daily | Maximum protection |
| [OISD Big](https://oisd.nl/) | ~3M | Daily | Very comprehensive |
| [1Hosts Pro](https://o0.pages.dev/Pro/adblock.txt) | ~500K | Daily | Aggressive blocking |
| [StevenBlack Unified](https://github.com/StevenBlack/hosts) | ~150K | Weekly | Classic, well-known |

**Total:** ~5 million domains  
**False Positives:** Moderate, requires whitelist management  
**Performance:** May be slower on limited hardware

**Setup:**
```bash
# Add via Pi-hole admin panel > Adlists:
https://cdn.jsdelivr.net/gh/hagezi/dns-blocklists@latest/wildcard/pro.plus.txt
https://big.oisd.nl/
https://o0.pages.dev/Pro/adblock.txt
https://raw.githubusercontent.com/StevenBlack/hosts/master/hosts
```

---

## Recommended Setup Script

Use this script to automatically configure optimal blocklists:

```bash
#!/usr/bin/env bash
# Optimal Blocklist Setup for Pi-hole v6

CONTAINER="${1:-pihole_primary}"
PRESET="${2:-balanced}"  # light, balanced, aggressive

setup_light() {
    echo "Setting up LIGHT blocklists..."
    docker exec "$CONTAINER" sqlite3 /etc/pihole/gravity.db \
        "DELETE FROM adlist; 
         INSERT INTO adlist (address, enabled, comment) VALUES 
         ('https://hosts.oisd.nl/basic/', 1, 'OISD Basic'),
         ('https://o0.pages.dev/Lite/adblock.txt', 1, '1Hosts Lite');"
}

setup_balanced() {
    echo "Setting up BALANCED blocklists (RECOMMENDED)..."
    docker exec "$CONTAINER" sqlite3 /etc/pihole/gravity.db \
        "DELETE FROM adlist;
         INSERT INTO adlist (address, enabled, comment) VALUES 
         ('https://hosts.oisd.nl/', 1, 'OISD Full'),
         ('https://cdn.jsdelivr.net/gh/hagezi/dns-blocklists@latest/wildcard/pro.txt', 1, 'Hagezi Pro'),
         ('https://www.github.developerdan.com/hosts/lists/ads-and-tracking-extended.txt', 1, 'Developer Dan Ads & Tracking');"
}

setup_aggressive() {
    echo "Setting up AGGRESSIVE blocklists..."
    docker exec "$CONTAINER" sqlite3 /etc/pihole/gravity.db \
        "DELETE FROM adlist;
         INSERT INTO adlist (address, enabled, comment) VALUES 
         ('https://cdn.jsdelivr.net/gh/hagezi/dns-blocklists@latest/wildcard/pro.plus.txt', 1, 'Hagezi Pro++'),
         ('https://big.oisd.nl/', 1, 'OISD Big'),
         ('https://o0.pages.dev/Pro/adblock.txt', 1, '1Hosts Pro'),
         ('https://raw.githubusercontent.com/StevenBlack/hosts/master/hosts', 1, 'StevenBlack Unified');"
}

case "$PRESET" in
    light)
        setup_light
        ;;
    balanced)
        setup_balanced
        ;;
    aggressive)
        setup_aggressive
        ;;
    *)
        echo "Unknown preset: $PRESET"
        echo "Usage: $0 [container] [light|balanced|aggressive]"
        exit 1
        ;;
esac

echo "Updating gravity database..."
docker exec "$CONTAINER" pihole updateGravity

echo "Done! Blocklists configured."
```

**Save as:** `scripts/setup-blocklists.sh`

**Usage:**
```bash
# Light preset
bash scripts/setup-blocklists.sh pihole_primary light

# Balanced preset (recommended)
bash scripts/setup-blocklists.sh pihole_primary balanced

# Aggressive preset
bash scripts/setup-blocklists.sh pihole_primary aggressive
```

---

## Essential Whitelists

Some domains need whitelisting to prevent breakage. Here are the most common:

### Streaming Services

```bash
# Disney+
pihole -w disneyplus.com disney-plus.net disneystreaming.com bamgrid.com dssott.com

# Netflix
pihole -w netflix.com nflxext.com nflximg.net nflxso.net nflxvideo.net

# Amazon Prime
pihole -w amazon.com amazonaws.com

# Hulu
pihole -w hulu.com hulustream.com

# HBO Max
pihole -w hbomax.com hbomaxcdn.com

# Apple TV+
pihole -w apple.com itunes.com
```

### Smart Home Devices

```bash
# Amazon Alexa
pihole -w device-metrics-us.amazon.com device-metrics-us-2.amazon.com

# Google Home
pihole -w clients4.google.com clients6.google.com

# Roku
pihole -w roku.com

# Samsung SmartThings
pihole -w samsungcloudsolution.com samsungelectronics.com
```

### Microsoft Services

```bash
# Windows Update
pihole -w windowsupdate.com update.microsoft.com

# Microsoft Office
pihole -w office.com office365.com

# Xbox Live
pihole -w xbox.com xboxlive.com
```

### Social Media

```bash
# Facebook/Instagram (if using)
pihole -w facebook.com fbcdn.net instagram.com

# WhatsApp
pihole -w whatsapp.com whatsapp.net
```

**Whitelist Script:**
```bash
#!/usr/bin/env bash
# Essential Whitelists for Common Services

CONTAINER="${1:-pihole_primary}"

# Streaming
docker exec "$CONTAINER" pihole -w \
    disneyplus.com disney-plus.net disneystreaming.com \
    netflix.com nflxext.com nflxvideo.net \
    amazon.com amazonaws.com \
    hulu.com hulustream.com

# Smart Home
docker exec "$CONTAINER" pihole -w \
    device-metrics-us.amazon.com \
    clients4.google.com clients6.google.com \
    roku.com

# Microsoft
docker exec "$CONTAINER" pihole -w \
    windowsupdate.com update.microsoft.com \
    office.com office365.com

echo "Essential whitelists configured!"
```

---

## Blocklist Categories (For Custom Setup)

If you want to customize, here are categorized lists:

### Ads & Tracking
- **OISD**: https://hosts.oisd.nl/ (all-in-one)
- **Hagezi Ads**: https://cdn.jsdelivr.net/gh/hagezi/dns-blocklists@latest/wildcard/multi.txt
- **EasyList**: https://v.firebog.net/hosts/Easylist.txt

### Malware & Security
- **URLhaus**: https://urlhaus.abuse.ch/downloads/hostfile/
- **Phishing Army**: https://phishing.army/download/phishing_army_blocklist_extended.txt
- **Malware Domain List**: https://www.malwaredomainlist.com/hostslist/hosts.txt

### Privacy & Tracking
- **EasyPrivacy**: https://v.firebog.net/hosts/Easyprivacy.txt
- **AdGuard Tracking**: https://adguardteam.github.io/AdGuardSDNSFilter/Filters/filter.txt

### Crypto Mining
- **Coin Blocker**: https://zerodot1.gitlab.io/CoinBlockerLists/hosts_browser

### Adult Content
- **OISD NSFW**: https://hosts.oisd.nl/nsfw/

---

## Performance Optimization

### For Raspberry Pi

**Recommended maximum:** 2-3 million domains
- More than this may cause slowdowns
- Monitor FTL memory usage: `docker exec pihole_primary pihole -c -e`

### Optimize Gravity Update

Add to `.env`:
```bash
# Speed up gravity updates
PIHOLE_GRAVITY_PARALLEL=1
```

### Regular Maintenance

```bash
# Compact database (run monthly)
docker exec pihole_primary pihole -g -r optimize

# Clear old query logs (run weekly)
docker exec pihole_primary pihole -f
```

---

## Update Strategy

### Automatic Updates (Recommended)

The auto-update service updates blocklists daily:
```yaml
environment:
  - UPDATE_INTERVAL=86400  # 24 hours
```

### Manual Updates

```bash
# Update gravity on all containers
bash scripts/pihole-auto-update.sh --once

# Or single container
docker exec pihole_primary pihole updateGravity
```

---

## Troubleshooting

### Site Not Loading

1. Check Pi-hole query log
2. Whitelist the domain:
   ```bash
   docker exec pihole_primary pihole -w example.com
   ```
3. Common culprits: CDNs, analytics, tracking domains

### Too Many Blocked Queries

- Use "Light" preset instead
- Review and whitelist false positives
- Check specific application requirements

### Slow Performance

- Reduce number of blocklists
- Use more targeted lists (e.g., OISD only)
- Increase Pi-hole cache size in FTL settings

---

## Recommended Configuration

**For most users, this is optimal:**

1. **Blocklists:** Balanced preset (OISD + Hagezi Pro + Developer Dan)
2. **Auto-update:** Daily (86400 seconds)
3. **Whitelists:** Streaming services + Windows Update
4. **Cache:** Default FTL settings
5. **Monitoring:** Check logs weekly for false positives

**Setup commands:**
```bash
# Set up balanced blocklists
bash scripts/setup-blocklists.sh pihole_primary balanced

# Add essential whitelists
bash scripts/setup-whitelist.sh pihole_primary

# Verify
docker exec pihole_primary pihole -g
docker exec pihole_primary pihole -c -e
```

---

## Additional Resources

- [Firebog - The Big Blocklist Collection](https://firebog.net/)
- [OISD Blocklists](https://oisd.nl/)
- [Hagezi DNS Blocklists](https://github.com/hagezi/dns-blocklists)
- [Pi-hole Discourse - Commonly Whitelisted](https://discourse.pi-hole.net/t/commonly-whitelisted-domains/212)

---

**This configuration blocks ads, trackers, and malware while maintaining compatibility with common services!** 🛡️
