# Smart Upgrade System Guide 🚀

Complete guide for the RPi HA DNS Stack Smart Upgrade System introduced in v2.4.0.

---

## Table of Contents

- [Overview](#overview)
- [Quick Start](#quick-start)
- [Features](#features)
- [Usage Guide](#usage-guide)
- [Upgrade Workflow](#upgrade-workflow)
- [Safety Features](#safety-features)
- [Troubleshooting](#troubleshooting)
- [Best Practices](#best-practices)
- [FAQ](#faq)

---

## Overview

The Smart Upgrade System is a comprehensive solution for managing updates to your RPi HA DNS Stack. It provides:

- **Automated Update Detection**: Checks for new Docker image versions
- **Safe Upgrade Process**: Pre-flight checks and post-upgrade validation
- **Automatic Backups**: Creates backups before any upgrade
- **Rollback Capability**: Easy recovery if something goes wrong
- **Interactive Interface**: User-friendly menu system
- **Detailed Logging**: Complete audit trail of all upgrades

### Why Use Smart Upgrade?

**Traditional Method:**
```bash
git pull
docker compose pull
docker compose up -d
# Cross your fingers... 🤞
```

**Smart Upgrade Method:**
```bash
bash scripts/smart-upgrade.sh -i
# ✓ System health verified
# ✓ Backup created automatically
# ✓ Updates applied safely
# ✓ Services validated
# ✓ Complete success report
```

---

## Quick Start

### 1. Check for Updates

```bash
cd ~/rpi-ha-dns-stack
bash scripts/smart-upgrade.sh -c
```

This will check all Docker images for available updates without making any changes.

### 2. Review Update Report

```bash
cat update-report.md
```

The report shows:
- Which images have updates available (🟡)
- Which are up to date (🟢)
- Recommended upgrade commands

### 3. Perform Upgrade

**Interactive Mode (Recommended):**
```bash
bash scripts/smart-upgrade.sh -i
```

Select option 2 for full system upgrade, or option 3 for specific stack.

**Direct Upgrade:**
```bash
bash scripts/smart-upgrade.sh -u
```

---

## Features

### Pre-Upgrade Checks ✓

Before any upgrade, the system verifies:

1. **Disk Space**: Ensures at least 15% free space
   - Warns if disk is >85% full
   - Prompts to continue or abort

2. **Docker Daemon**: Confirms Docker is running
   - Exits if Docker is not available
   - Checks Docker socket accessibility

3. **Network Connectivity**: Tests internet connection
   - Pings 8.8.8.8 to verify connectivity
   - Allows offline upgrade if needed

4. **Running Services**: Inventories active containers
   - Counts critical DNS services
   - Reports current service state

### Automatic Backup 💾

Before any upgrade:
- Calls `scripts/automated-backup.sh` automatically
- Creates timestamped backup in `/backups/`
- Includes all Pi-hole data, Grafana dashboards, etc.
- Enables one-click rollback if needed

### Selective Upgrades 🎯

Upgrade options:
- **Full System**: All stacks upgraded together
- **DNS Stack**: Pi-hole and Unbound only
- **Observability**: Grafana, Prometheus, Loki, etc.
- **Management**: Portainer, Homepage, Uptime Kuma
- **Backup**: Backup service
- **AI Watchdog**: Monitoring and self-healing
- **SSO**: Authelia and OAuth2 Proxy (if installed)
- **VPN**: WireGuard stack (if installed)

### Post-Upgrade Validation ✓

After upgrade, the system checks:

1. **Container Health**: Verifies healthcheck status
   - Reports unhealthy containers
   - Suggests remediation

2. **DNS Resolution**: Tests both Pi-hole instances
   - Queries google.com via each instance
   - Confirms recursive DNS working

3. **Service Availability**: Confirms critical services running
   - Counts running containers
   - Compares to pre-upgrade state

### Comprehensive Logging 📝

All operations logged to `upgrade.log`:
- Timestamp for each action
- Pre-upgrade checks results
- Upgrade progress
- Post-upgrade validation
- Final summary

View logs:
```bash
cat upgrade.log
# Or
tail -f upgrade.log  # During upgrade
```

---

## Usage Guide

### Command-Line Options

```bash
bash scripts/smart-upgrade.sh [OPTIONS]
```

| Option | Description | Example |
|--------|-------------|---------|
| `-h, --help` | Show help message | `bash scripts/smart-upgrade.sh -h` |
| `-i, --interactive` | Interactive menu mode | `bash scripts/smart-upgrade.sh -i` |
| `-c, --check` | Check for updates only | `bash scripts/smart-upgrade.sh -c` |
| `-u, --upgrade` | Perform full system upgrade | `bash scripts/smart-upgrade.sh -u` |
| `-s, --stack <name>` | Upgrade specific stack | `bash scripts/smart-upgrade.sh -s dns` |
| `-v, --verify` | Verify system health only | `bash scripts/smart-upgrade.sh -v` |
| `--create-version-file` | Create version tracking file | `bash scripts/smart-upgrade.sh --create-version-file` |
| `--no-backup` | Skip pre-upgrade backup | `bash scripts/smart-upgrade.sh -u --no-backup` |

### Interactive Mode Menu

```
╔════════════════════════════════════════════════════════════════╗
║            RPi HA DNS Stack - Smart Upgrade System             ║
║                        Version 2.4.0                           ║
╚════════════════════════════════════════════════════════════════╝

What would you like to do?

  1) Check for available updates
  2) Perform full system upgrade
  3) Upgrade specific stack only
  4) Create version tracking file
  5) View upgrade history
  6) Exit
```

### Available Stacks

When using `-s` or option 3:
- `dns` - Pi-hole and Unbound DNS services
- `observability` - Grafana, Prometheus, Loki, Alertmanager
- `management` - Portainer, Homepage, Uptime Kuma, Netdata
- `backup` - Automated backup service
- `ai-watchdog` - Container monitoring and self-healing
- `sso` - Authelia SSO and OAuth2 Proxy
- `vpn` - WireGuard VPN (if deployed)
- `remote-access` - Tailscale, Cloudflare Tunnel (if deployed)

---

## Upgrade Workflow

### Full Upgrade Flow

```
START
  ├─ Initialize upgrade log
  ├─ Pre-Upgrade Health Check
  │   ├─ Check disk space (>15% free required)
  │   ├─ Verify Docker daemon running
  │   ├─ Test network connectivity
  │   └─ Inventory running containers
  ├─ Create Automatic Backup
  │   └─ Call automated-backup.sh
  ├─ Check for Updates
  │   ├─ Query Docker Hub API
  │   ├─ Compare image digests
  │   └─ Generate update report
  ├─ User Confirmation
  │   └─ "Proceed with upgrade? (Y/n)"
  ├─ Upgrade All Stacks
  │   ├─ For each stack:
  │   │   ├─ Pull latest images
  │   │   ├─ Recreate containers
  │   │   └─ Wait for healthy
  │   └─ Sleep 2s between stacks
  ├─ Post-Upgrade Verification
  │   ├─ Check container health
  │   ├─ Test DNS resolution
  │   └─ Verify service availability
  ├─ Show Upgrade Summary
  │   ├─ Services upgraded
  │   ├─ Next steps
  │   └─ Rollback instructions
  └─ END
```

### Selective Stack Upgrade Flow

```
START
  ├─ Validate stack name
  ├─ Check stack directory exists
  ├─ Pull latest images for stack
  ├─ Recreate containers
  ├─ Wait for healthy status
  └─ END
```

---

## Safety Features

### 1. Pre-Flight Validation

**Disk Space Check:**
```
Performing pre-upgrade health check...

✓ Disk space OK: 42% used
```

If disk >85% full:
```
⚠ WARNING: Disk usage is high: 87% - Consider cleaning up before upgrade
Continue anyway? (y/N):
```

**Docker Status:**
```
✓ Docker daemon running
```

If Docker not running:
```
✗ ERROR: Docker daemon is not running!
```

**Network Test:**
```
✓ Network connectivity OK
```

If no internet:
```
⚠ WARNING: No internet connectivity - cannot pull updates
Continue with offline upgrade? (y/N):
```

### 2. Automatic Backup

Before every upgrade:
```
Creating pre-upgrade backup...
✓ Pre-upgrade backup created successfully
Backup location: /opt/rpi-ha-dns-stack/backups/stack_backup_20241119_143022.tar.gz
```

### 3. Rollback Capability

If upgrade fails or causes issues:

```bash
# List available backups
ls -lh backups/stack_backup_*.tar.gz

# Restore from backup
bash scripts/restore-backup.sh

# Select the pre-upgrade backup
# Follow prompts to restore
```

### 4. Health Validation

After upgrade:
```
Performing post-upgrade verification...

✓ All containers are healthy
✓ DNS resolution working (primary)
✓ DNS resolution working (secondary)

✓ Post-upgrade verification complete
```

If issues detected:
```
⚠ WARNING: Found 2 unhealthy containers:
pihole_primary    Up 30 seconds (unhealthy)
grafana           Up 25 seconds (unhealthy)

Some containers may need attention
```

---

## Troubleshooting

### Problem: Disk Space Warning

```
⚠ WARNING: Disk usage is high: 89%
```

**Solution:**
```bash
# Clean Docker system
docker system prune -a

# Remove old backups
cd backups
rm stack_backup_2024*.tar.gz  # Keep only recent ones

# Clear Docker build cache
docker builder prune
```

### Problem: Docker Permission Denied

```
✗ ERROR: Docker daemon is not running!
```

**Solution:**
```bash
# Check Docker status
sudo systemctl status docker

# Start Docker if stopped
sudo systemctl start docker

# Add user to docker group
sudo usermod -aG docker $USER
newgrp docker
```

### Problem: Container Unhealthy After Upgrade

```
⚠ WARNING: Found 1 unhealthy container:
pihole_primary    Up 60 seconds (unhealthy)
```

**Solution:**
```bash
# Check container logs
docker logs pihole_primary

# Restart the container
docker restart pihole_primary

# If persistent, rollback
bash scripts/restore-backup.sh
```

### Problem: Network Connectivity Failed

```
⚠ WARNING: No internet connectivity
```

**Solution:**
```bash
# Check network
ping 8.8.8.8

# Check DNS resolution
nslookup google.com

# If offline mode needed:
bash scripts/smart-upgrade.sh -u
# Select "y" when prompted for offline upgrade
```

### Problem: Upgrade Stuck

**Solution:**
```bash
# Open another terminal
docker ps -a

# Check which container is stuck
docker logs <container-name>

# Force stop if needed
docker stop <container-name>

# Resume upgrade or rollback
bash scripts/restore-backup.sh
```

---

## Best Practices

### 1. Regular Update Checks

**Recommended Schedule:**
```bash
# Add to crontab for weekly checks
crontab -e

# Add this line:
0 3 * * 0 /opt/rpi-ha-dns-stack/scripts/check-updates.sh
```

Every Sunday at 3 AM, check for updates and generate report.

### 2. Upgrade During Maintenance Window

- Upgrade during low-traffic periods
- Sunday mornings (2-4 AM) recommended
- Avoid upgrades during critical times

### 3. Always Review Update Report

```bash
# Before upgrading, check report
bash scripts/smart-upgrade.sh -c
cat update-report.md

# Review what will be updated
# Check release notes for major updates
```

### 4. Test Before Production

If you have a test environment:
```bash
# Test upgrade on dev system first
bash scripts/smart-upgrade.sh -u

# Monitor for 24-48 hours
# Then upgrade production
```

### 5. Keep Backups

```bash
# Manual backup before major upgrades
bash scripts/automated-backup.sh

# Verify backup exists
ls -lh backups/

# Test restore occasionally
bash scripts/restore-backup.sh
# (Select test backup, restore to verify process)
```

### 6. Monitor After Upgrade

**First 30 minutes:**
- Check Grafana dashboards
- Verify DNS resolution
- Check container logs

**First 24 hours:**
- Monitor error rates
- Check AI Watchdog alerts
- Review Prometheus metrics

**First week:**
- Watch for memory leaks
- Check disk usage trends
- Verify backup completion

---

## FAQ

### Q: How often should I upgrade?

**A:** Recommended schedule:
- **Security updates**: Within 7 days of release
- **Regular updates**: Monthly
- **Major versions**: After 2-4 weeks of testing

### Q: Can I upgrade just Pi-hole?

**A:** Yes!
```bash
bash scripts/smart-upgrade.sh -s dns
```

This upgrades only the DNS stack (Pi-hole + Unbound).

### Q: What if an upgrade fails?

**A:** The system creates automatic backups. To rollback:
```bash
bash scripts/restore-backup.sh
```

Select the pre-upgrade backup and confirm restore.

### Q: Do I need to stop services manually?

**A:** No. The upgrade script handles:
- Pulling new images
- Recreating containers
- Zero-downtime rolling updates

### Q: Can I schedule automatic upgrades?

**A:** Partially. You can:
1. Schedule update checks (recommended)
2. Use Watchtower for specific services
3. Manual approval still recommended for full upgrades

**Not recommended:** Fully automated upgrades without approval.

### Q: How do I check what version I'm running?

**A:**
```bash
# Check stack version
grep "stack_version" .versions.yml

# Check specific service
docker inspect pihole_primary | grep -i version

# View all container images
docker ps --format "table {{.Names}}\t{{.Image}}"
```

### Q: What gets upgraded?

**A:** All Docker images:
- Pi-hole
- Unbound
- Grafana stack (Grafana, Prometheus, Loki, etc.)
- Management tools (Portainer, Homepage, etc.)
- Optional stacks (SSO, VPN, etc.)

Configuration files are NOT changed unless you `git pull`.

### Q: Can I skip the backup?

**A:** Yes, but not recommended:
```bash
bash scripts/smart-upgrade.sh -u --no-backup
```

Only skip if you have recent manual backup.

### Q: How long does an upgrade take?

**A:** Typical timing:
- Pre-checks: 30 seconds
- Backup: 2-5 minutes
- Image pulls: 5-15 minutes (depends on internet)
- Container recreation: 2-5 minutes
- Post-verification: 1 minute
- **Total: 10-30 minutes**

### Q: Will I lose DNS service during upgrade?

**A:** Minimal disruption:
- High Availability setup: Near-zero downtime
  - Secondary Pi-hole serves while primary upgrades
  - Then primary serves while secondary upgrades
- Single Pi setup: ~30-60 seconds of downtime per service

### Q: Can I upgrade multiple Raspberry Pis?

**A:** For multi-node setups:
```bash
# On each node:
cd ~/rpi-ha-dns-stack
bash scripts/smart-upgrade.sh -u

# Upgrade one node at a time
# Wait for health check before next node
```

---

## Advanced Usage

### Custom Upgrade Scripts

Create custom upgrade workflow:

```bash
#!/bin/bash
# custom-upgrade.sh

# Check for updates
bash scripts/smart-upgrade.sh -c

# Only upgrade if critical services have updates
if grep -q "pihole.*Update Available" update-report.md; then
    # Backup
    bash scripts/automated-backup.sh
    
    # Upgrade DNS only
    bash scripts/smart-upgrade.sh -s dns
    
    # Verify
    bash scripts/smart-upgrade.sh -v
    
    # Notify
    curl -X POST http://localhost:8080/notify \
        -d '{"message": "DNS stack upgraded successfully"}'
fi
```

### Integration with Monitoring

Alert when updates available:

```yaml
# prometheus/rules/updates.yml
groups:
  - name: updates
    interval: 1h
    rules:
      - alert: UpdatesAvailable
        expr: time() - update_check_timestamp > 86400
        annotations:
          summary: "Check for updates"
          description: "Run update check: bash scripts/check-updates.sh"
```

### Version Pinning

For production stability, pin versions:

```yaml
# .versions.yml
services:
  pihole:
    image: pihole/pihole
    version: 2024.07.0  # Specific version
    auto_update: false  # Disable auto-update
```

Then manually upgrade after testing:
```bash
# Edit docker-compose.yml
image: pihole/pihole:2024.07.0

# Rebuild
docker compose up -d
```

---

## Upgrade Checklist

Use this checklist for production upgrades:

### Before Upgrade
- [ ] Review update report (`cat update-report.md`)
- [ ] Check release notes for breaking changes
- [ ] Verify disk space >15% free
- [ ] Confirm backup system working
- [ ] Schedule during maintenance window
- [ ] Notify users of potential brief outage

### During Upgrade
- [ ] Run `bash scripts/smart-upgrade.sh -u`
- [ ] Monitor progress in real-time
- [ ] Watch for errors in upgrade.log
- [ ] Verify pre-upgrade backup created
- [ ] Confirm post-upgrade validation passes

### After Upgrade
- [ ] Check all services accessible
- [ ] Test DNS resolution from client devices
- [ ] Review Grafana dashboards
- [ ] Check container logs for errors
- [ ] Verify AI Watchdog operational
- [ ] Monitor for 30 minutes minimum
- [ ] Keep backup for 7 days
- [ ] Update documentation if needed
- [ ] Notify users upgrade complete

---

## Support

### Getting Help

**Documentation:**
- This guide (SMART_UPGRADE_GUIDE.md)
- Main README.md
- VERSIONS.md changelog
- TROUBLESHOOTING.md

**Logs:**
```bash
# Upgrade log
cat upgrade.log

# Update report
cat update-report.md

# Container logs
docker logs <container-name>

# Health check
bash scripts/health-check.sh
```

**Community:**
- GitHub Issues: Report bugs or request features
- Discussions: Ask questions

---

## Version History

### v2.4.0 (2024-11-19)
- Initial release of Smart Upgrade System
- Automated update checking
- Interactive upgrade interface
- Pre/post upgrade validation
- Automatic backup integration

---

**Happy Upgrading! 🚀**

For questions or issues, please open a GitHub issue or refer to the troubleshooting guide.
