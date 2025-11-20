# DNS Security and Privacy Profiles

Security and privacy filtering profiles for Pi-hole DNS blocking.

## Overview

Orion Sentinel DNS HA provides three pre-configured security profiles to suit different needs:

| Profile | Use Case | Blocking Level | Content Filtering |
|---------|----------|----------------|-------------------|
| **Standard** | General home/office use | Moderate | Ads + Malware only |
| **Family** | Families with children | High | Ads + Malware + Adult content |
| **Paranoid** | Privacy-focused users | Very High | Aggressive tracking + telemetry |

## Profile Descriptions

### Standard Profile

**Purpose**: Balanced protection for general use

**What it blocks:**
- ✅ Advertisements and ad networks
- ✅ Known malware domains
- ✅ Phishing sites
- ✅ Web trackers
- ❌ Adult content (not blocked)
- ❌ Social media (not blocked)

**Blocklists:**
- StevenBlack Unified Hosts
- AdGuard DNS Filter
- Malware Domain List
- Phishing Army
- EasyPrivacy
- Disconnect Tracking

**Best for:**
- Home users without children
- Small offices
- Users who want ad-blocking without breaking websites

**Expected side effects:** Minimal - most websites work normally

---

### Family Profile

**Purpose**: Family-safe internet with content filtering

**What it blocks:**
- ✅ Everything in Standard profile
- ✅ Adult content and pornography
- ✅ Gambling sites
- ✅ Fake news sites
- ✅ Enhanced malware protection
- ❌ Social media (optional, configurable)

**Additional blocklists:**
- StevenBlack Fakenews + Gambling + Porn
- AdGuard Family Protection
- URLhaus Malware
- Additional suspicious domain lists

**Best for:**
- Families with children
- Schools or educational institutions
- Parents who want safer internet for kids

**Whitelisted services:**
- Educational sites (*.edu, classroom.google.com)
- Safe streaming (Disney+, Netflix)
- Gaming consoles (Xbox, PlayStation)
- Video calls (Teams, Zoom)

**Expected side effects:** 
- Some adult-oriented content blocked
- Gambling sites unavailable
- May need to whitelist specific sites for adults

---

### Paranoid Profile

**Purpose**: Maximum privacy and security

**What it blocks:**
- ✅ Everything in Standard profile
- ✅ Telemetry (Windows, Apple, Google)
- ✅ Social media tracking widgets
- ✅ Smart TV telemetry and ads
- ✅ Analytics and metrics collection
- ✅ Tracking beacons
- ✅ Aggressive ad networks

**Additional blocklists:**
- Windows Spy Blocker
- Apple Telemetry Blocker
- Fanboy Social Blocking
- Smart TV Blocklist
- Amazon Fire TV tracking
- Privacy-focused hosts lists

**Best for:**
- Privacy-conscious users
- Users who don't mind occasional website breakage
- Advanced users who can troubleshoot issues

**Whitelisted services:** Minimal (only essential updates and certificate validation)

**Expected side effects:**
- ⚠️ Many websites may not function properly
- ⚠️ Social media features often broken
- ⚠️ Embedded content may not load
- ⚠️ Cloud services may have issues
- ⚠️ Smart TVs may lose some features

**Warning:** This profile blocks aggressively. Start with Standard and migrate gradually.

---

## Applying Profiles

### Using the Profile Tool

Apply a profile using the `apply-profile.py` script:

```bash
# Dry-run (see what would be changed)
python3 scripts/apply-profile.py --profile standard --dry-run

# Apply standard profile
python3 scripts/apply-profile.py --profile standard

# Apply family profile
python3 scripts/apply-profile.py --profile family

# Apply paranoid profile  
python3 scripts/apply-profile.py --profile paranoid

# Specify Pi-hole IP (if not using default)
python3 scripts/apply-profile.py --profile standard --pihole-ip 192.168.8.251
```

### What the Tool Does

1. Reads the profile YAML file
2. Connects to Pi-hole API
3. Adds/removes blocklists as specified
4. Updates whitelist entries
5. Applies regex blocking patterns
6. Updates Pi-hole gravity database
7. Restarts DNS services if needed

### Manual Application

If you prefer manual configuration:

1. Open Pi-hole admin interface: http://192.168.8.251/admin
2. Navigate to **Group Management > Adlists**
3. Add URLs from the profile's `blocklists` section
4. Navigate to **Whitelist** and add domains from `whitelist` section
5. Navigate to **Group Management > Domains** and add regex patterns
6. Click **Update Gravity** to apply changes

## Customizing Profiles

### Create a Custom Profile

Copy an existing profile and modify:

```bash
# Copy standard profile as template
cp profiles/standard.yml profiles/my-custom.yml

# Edit the profile
nano profiles/my-custom.yml

# Apply your custom profile
python3 scripts/apply-profile.py --profile profiles/my-custom.yml
```

### Profile YAML Structure

```yaml
name: my-custom
description: My custom DNS filtering profile
category: custom

blocklists:
  - name: "Custom Blocklist"
    url: "https://example.com/blocklist.txt"
    enabled: true
    description: "My specific needs"

whitelist:
  - name: "Work Services"
    domains:
      - "work.example.com"
      - "*.company.net"
    reason: "Required for work"

regex_patterns:
  - pattern: "^ads?[0-9]*\\."
    description: "Block ad subdomains"
    enabled: true

settings:
  privacy_level: 0
  cache_size: 10000
```

## Profile Migration

### Switching Profiles

When switching profiles, the tool will:
1. Backup current configuration
2. Remove old blocklists
3. Add new blocklists
4. Update gravity
5. Verify changes

```bash
# Switch from standard to family
python3 scripts/apply-profile.py --profile family

# Switch back to standard
python3 scripts/apply-profile.py --profile standard
```

### Gradual Migration to Paranoid

Don't jump directly to paranoid. Migrate gradually:

1. **Week 1**: Apply standard profile, use normally
2. **Week 2**: Note what you want blocked, switch to family
3. **Week 3**: Add custom blocklists to family profile
4. **Week 4**: Test paranoid in dry-run mode
5. **Week 5**: Apply paranoid, whitelist as needed

### Whitelisting Workflow

When using aggressive profiles:

1. Browse normally and note what breaks
2. Check Pi-hole query log (Admin > Query Log)
3. Find the blocked domain causing issues
4. Add to whitelist:
   ```bash
   docker exec pihole_primary pihole -w example.com
   ```
5. Test if issue is resolved
6. Add to your custom profile YAML for persistence

## Profile Maintenance

### Updating Blocklists

Blocklists update automatically via Pi-hole's gravity update:

```bash
# Manual gravity update
docker exec pihole_primary pihole -g

# Check when last updated
docker exec pihole_primary pihole -c
```

### Scheduled Updates

Add to crontab for weekly updates:

```bash
# Every Sunday at 3 AM
0 3 * * 0 docker exec pihole_primary pihole -g
```

### Monitoring Block Effectiveness

Check Pi-hole dashboard to see:
- Total queries blocked
- Block percentage
- Top blocked domains
- Top clients

Access at: http://192.168.8.251/admin

## Common Customizations

### Block Social Media (Family Profile)

Add to whitelist section:
```yaml
- name: "Block Social Media"
  regex_patterns:
    - pattern: "(facebook|twitter|instagram|tiktok)\\.com$"
      enabled: true
```

### Allow Gaming (Paranoid Profile)

Add to whitelist:
```yaml
- name: "Gaming Services"
  domains:
    - "steam.com"
    - "epicgames.com"
    - "battle.net"
    - "*.riotgames.com"
```

### Block Cryptocurrency Miners

Add to any profile:
```yaml
- name: "Crypto Mining Protection"
  url: "https://raw.githubusercontent.com/Marfjeh/coinhive-block/master/domains"
  enabled: true
```

## Troubleshooting

### Profile Application Fails

**Error**: "Cannot connect to Pi-hole API"

**Solution**:
```bash
# Check Pi-hole is running
docker ps | grep pihole

# Check network connectivity
ping 192.168.8.251

# Verify Pi-hole password in .env file
grep PIHOLE_PASSWORD .env
```

### Website Broken After Applying Profile

**Diagnosis**:
1. Check Pi-hole Query Log
2. Find recently blocked domains
3. Test each domain individually

**Solution**:
```bash
# Temporarily whitelist domain
docker exec pihole_primary pihole -w suspicious-domain.com

# Test if website works
# If yes, add to permanent whitelist in profile
```

### Too Many Domains Blocked

**Solution**: Switch to a less aggressive profile

```bash
# Switch from paranoid to standard
python3 scripts/apply-profile.py --profile standard
```

## Best Practices

1. **Start conservative**: Begin with standard profile
2. **Test changes**: Use dry-run mode before applying
3. **Monitor logs**: Watch query logs for a few days after changes
4. **Document whitelists**: Keep track of what you whitelist and why
5. **Backup regularly**: Run backup before major profile changes
6. **Review periodically**: Check if blocklists are still maintained
7. **Update gravity**: Run gravity update weekly

## See Also

- [Health and HA Guide](health-and-ha.md) - Health checking and failover
- [Backup and Migration](backup-and-migration.md) - Configuration backups
- [Observability](observability.md) - Monitor blocking effectiveness
- [Pi-hole Documentation](https://docs.pi-hole.net/) - Official Pi-hole docs
