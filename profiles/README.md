# DNS Security Profiles

Pre-configured DNS filtering profiles for Pi-hole.

## Quick Start

Apply a profile to your Pi-hole instance:

```bash
# View available profiles
ls -1 *.yml
# family.yml
# paranoid.yml
# standard.yml

# Apply standard profile (recommended)
python3 ../scripts/apply-profile.py --profile standard

# Preview changes without applying
python3 ../scripts/apply-profile.py --profile family --dry-run

# Apply to specific Pi-hole instance
python3 ../scripts/apply-profile.py --profile paranoid --pihole-ip 192.168.8.251
```

## Available Profiles

### standard.yml
**Balanced protection for general use**

- ✅ Ad blocking
- ✅ Malware protection
- ✅ Basic tracking protection
- ❌ No content filtering

**Best for**: Home users, small offices

### family.yml
**Family-safe internet with content filtering**

- ✅ Everything in standard
- ✅ Adult content blocking
- ✅ Gambling site blocking
- ✅ Enhanced malware protection

**Best for**: Families with children, schools

### paranoid.yml
**Maximum privacy and security**

- ✅ Everything in standard
- ✅ Aggressive telemetry blocking (Windows, Apple, Google)
- ✅ Social media tracking blockers
- ✅ Smart TV ad blocking

**Best for**: Privacy-conscious users

⚠️ **Warning**: May break some websites and services

## Profile Structure

Each profile YAML file contains:

```yaml
name: profile-name
description: Profile description
category: standard|family-safe|privacy-focused

# Blocklists to apply
blocklists:
  - name: "List Name"
    url: "https://example.com/blocklist.txt"
    enabled: true
    description: "What this blocks"

# Domains to whitelist
whitelist:
  - name: "Category Name"
    domains:
      - "example.com"
      - "*.example.net"
    reason: "Why this is whitelisted"

# Regex blocking patterns
regex_patterns:
  - pattern: "^ads?[0-9]*\\."
    description: "Block ad subdomains"
    enabled: true

# Pi-hole settings
settings:
  privacy_level: 0  # 0-3
  cache_size: 10000
  blocking_mode: "NULL"
```

## Creating Custom Profiles

1. Copy an existing profile as template:
   ```bash
   cp standard.yml my-custom.yml
   ```

2. Edit the profile:
   ```bash
   nano my-custom.yml
   ```

3. Apply your custom profile:
   ```bash
   python3 ../scripts/apply-profile.py --profile my-custom.yml
   ```

## Documentation

For complete documentation, see: **[docs/profiles.md](../docs/profiles.md)**

Topics covered:
- Detailed profile descriptions
- Profile migration and switching
- Customization guide
- Whitelisting workflow
- Troubleshooting
- Best practices

## Profile Tool Usage

```bash
# Basic usage
python3 scripts/apply-profile.py --profile PROFILE_NAME

# Options
--profile PROFILE      Profile name or path to YAML file
--pihole-ip IP        Pi-hole IP address (default: 192.168.8.251)
--pihole-password PW  Pi-hole admin password (default: from env)
--dry-run             Show changes without applying
--help                Show help message

# Examples
python3 scripts/apply-profile.py --profile standard
python3 scripts/apply-profile.py --profile /path/to/custom.yml --dry-run
```

## What the Tool Does

When you apply a profile:

1. ✅ Connects to Pi-hole API
2. ✅ Adds blocklists from profile
3. ✅ Updates whitelist
4. ✅ Applies regex patterns
5. ✅ Updates Pi-hole gravity database
6. ✅ Verifies changes

## Profile Maintenance

Blocklists update automatically via Pi-hole's gravity update:

```bash
# Manual update
docker exec pihole_primary pihole -g

# Schedule weekly updates
0 3 * * 0 docker exec pihole_primary pihole -g
```

## Support

For issues or questions:
1. Check the [profiles documentation](../docs/profiles.md)
2. Review [troubleshooting guide](../TROUBLESHOOTING.md)
3. Open an issue on GitHub
