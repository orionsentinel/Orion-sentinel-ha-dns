# Smart Upgrade Quick Reference Card

## Quick Commands

```bash
# Check for updates
bash scripts/smart-upgrade.sh -c

# View update report
cat update-report.md

# Interactive mode
bash scripts/smart-upgrade.sh -i

# Full upgrade
bash scripts/smart-upgrade.sh -u

# Upgrade DNS only
bash scripts/smart-upgrade.sh -s dns

# Security-enhanced upgrade
bash scripts/secure-upgrade.sh -u

# Verify system health
bash scripts/smart-upgrade.sh -v

# View upgrade history
cat upgrade.log
```

## Upgrade Checklist

### Before Upgrade
- [ ] Check disk space: `df -h`
- [ ] Review update report: `cat update-report.md`
- [ ] Verify backup system: `ls -lh backups/`
- [ ] Schedule maintenance window

### During Upgrade
- [ ] Run: `bash scripts/smart-upgrade.sh -u`
- [ ] Monitor progress
- [ ] Watch for errors in output

### After Upgrade
- [ ] Verify services running: `docker ps`
- [ ] Test DNS resolution: `nslookup google.com 192.168.8.251`
- [ ] Check Grafana dashboards
- [ ] Monitor for 30 minutes

### If Issues Occur
- [ ] Check logs: `cat upgrade.log`
- [ ] View container logs: `docker logs <container>`
- [ ] Rollback if needed: `bash scripts/restore-backup.sh`

## Available Stacks

- `dns` - Pi-hole + Unbound
- `observability` - Grafana, Prometheus, Loki
- `management` - Portainer, Homepage, Uptime Kuma
- `backup` - Automated backup service
- `ai-watchdog` - Container monitoring
- `sso` - Authelia SSO (if installed)
- `vpn` - WireGuard (if installed)

## Status Indicators

- 🟢 Up to date - No action needed
- 🟡 Update available - Consider upgrading
- ⚪ Not installed - N/A
- ❓ Unknown - Check manually

## Safety Features

✅ Pre-upgrade health checks
✅ Automatic backup creation
✅ Post-upgrade verification
✅ Rollback capability
✅ Detailed logging

## Common Scenarios

### Weekly Maintenance
```bash
# Check for updates
bash scripts/check-updates.sh

# Review report
cat update-report.md

# If updates available:
bash scripts/smart-upgrade.sh -u
```

### Emergency Security Patch
```bash
# Security-enhanced upgrade
bash scripts/secure-upgrade.sh -u
```

### Selective Upgrade
```bash
# Upgrade only DNS
bash scripts/smart-upgrade.sh -s dns
```

### Rollback After Failed Upgrade
```bash
# Restore from backup
bash scripts/restore-backup.sh

# Select pre-upgrade backup
# Confirm restore
```

## Automated Checks

Setup daily update monitoring:
```bash
# Add to crontab
crontab -e

# Add this line:
0 3 * * * /opt/rpi-ha-dns-stack/scripts/check-updates.sh
```

## Help & Documentation

- Full guide: `SMART_UPGRADE_GUIDE.md`
- Changelog: `CHANGELOG.md`
- Versions: `VERSIONS.md`
- Help: `bash scripts/smart-upgrade.sh --help`

## Emergency Contacts

- Check logs: `cat upgrade.log`
- Docker logs: `docker logs <container>`
- Health check: `bash scripts/health-check.sh`
- GitHub Issues: Report bugs or get help

---

**Pro Tip**: Always backup before upgrading!
```bash
bash scripts/automated-backup.sh
```
