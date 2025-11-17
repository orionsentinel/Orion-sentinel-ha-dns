# RPi HA DNS Stack - Version History

This document tracks all changes, improvements, and bug fixes for the RPi HA DNS Stack project.

---

## Version 2.3.0 (2024-11-17) - DNS Analytics & Enhanced Backup

### 🎯 Overview
Added comprehensive DNS query analytics with visual Grafana dashboard and enhanced automated backup solution with full restore capability.

### 📊 DNS Query Analytics

#### Grafana Dashboard - Pi-hole DNS Analytics
**New Dashboard:** Complete visual analytics for DNS queries and blocking effectiveness

**Panels Included:**
1. **Overview Stats (Top Row)**
   - Total DNS Queries (24h)
   - Ads Blocked Today
   - Block Rate Percentage
   - Domains on Blocklist

2. **Query Performance**
   - DNS Query Rate (queries/min) - Line chart showing forwarded vs cached
   - Ads Blocking Rate (blocks/min) - Trend visualization
   - DNS Query Response Time - Performance monitoring per instance

3. **Query Analysis**
   - Query Distribution - Pie chart (Forwarded/Cached/Blocked)
   - Top 10 Queried Domains - Table with query counts
   - Top 10 Blocked Domains - Table with block counts
   - Hourly Query Volume - Bar chart for last 24 hours

**Features:**
- Real-time data with 30-second refresh
- Prometheus data source integration
- Interactive tooltips and legends
- Mean/Max/Last values in legends
- Professional dark theme
- Auto-provisioned on Grafana startup

**Access:** Grafana → Dashboards → Pi-hole DNS Analytics

### 💾 Enhanced Automated Backup Solution

#### New Backup System
**Completely rewritten backup solution** with comprehensive coverage and restore capability.

**Previous System:**
- Simple tar backup of volumes
- No metadata
- No restore capability
- Manual process

**New System:**
- Intelligent Docker-aware backups
- Comprehensive metadata tracking
- Interactive restore utility
- Automated scheduling with cron
- Detailed logging

#### What Gets Backed Up

**DNS Services:**
- Pi-hole Primary: Configuration, gravity.db, custom lists, teleporter exports
- Pi-hole Secondary: Configuration, gravity.db, custom lists, teleporter exports  
- Unbound 1 & 2: Configuration files

**Observability:**
- Prometheus: Metrics data and API snapshots
- Grafana: Dashboards, datasources, users, settings

**Management Services:**
- Portainer: Stacks, environments, settings
- Uptime Kuma: Monitors, status pages, notifications
- Netdata: Configuration files

**Configurations:**
- All docker-compose.yml files
- Environment variables (.env files)
- Provisioning configs
- Homepage dashboard configs

#### New Scripts

**1. automated-backup.sh (9.9KB)**
- Complete backup orchestration
- Docker volume access via exec
- Compression with tar.gz
- Metadata generation
- Automatic retention cleanup
- Comprehensive logging
- Progress indicators

**2. restore-backup.sh (9.9KB)**
- Interactive backup selection
- Backup information display
- Safety confirmations
- Service stop/start management
- Data restoration per service
- Cleanup and verification

#### Backup Features

**Automated Scheduling:**
- Runs via cron (default: daily at 2 AM)
- Customizable schedule via `BACKUP_SCHEDULE` env variable
- Initial backup 60 seconds after startup

**Smart Retention:**
- Automatic cleanup based on `BACKUP_RETENTION_DAYS`
- Default: 7 days retention
- Statistics tracking (count, size, oldest)

**Metadata Tracking:**
```
BACKUP_INFO.txt contains:
- Backup timestamp
- Hostname and stack version
- Running containers list
- Backup contents inventory
- Total backup size
```

**Compression:**
- Efficient tar.gz format
- Typical size: 100MB-2GB depending on data
- Named: `stack_backup_YYYYMMDD_HHMMSS.tar.gz`

#### Restore Process

**Interactive Restore:**
```bash
bash /opt/rpi-ha-dns-stack/scripts/restore-backup.sh
```

**Steps:**
1. Lists all available backups with size and date
2. User selects backup to restore
3. Displays backup information
4. Confirms destructive operation
5. Stops all services
6. Restores configurations
7. Restores service data
8. Restarts services
9. Cleanup and verification

**Safety Features:**
- Confirmation required before restore
- Current configs backed up before overwrite
- Services properly stopped/started
- Error handling and warnings
- Comprehensive status messages

#### Deployment

**Docker Compose Service:**
```yaml
backup-service:
  - Runs on Alpine Linux
  - Docker socket access (read-only)
  - Cron scheduler
  - Health checks
  - Resource limits
  - Auto-restart
```

**Environment Variables:**
```bash
TZ=UTC                          # Timezone
BACKUP_RETENTION_DAYS=7         # Days to keep backups
BACKUP_SCHEDULE=0 2 * * *       # Cron schedule
```

**Quick Start:**
```bash
cd /opt/rpi-ha-dns-stack/stacks/backup
docker compose up -d
```

#### Backup Management

**Manual Backup:**
```bash
bash /opt/rpi-ha-dns-stack/scripts/automated-backup.sh
```

**List Backups:**
```bash
ls -lh /opt/rpi-ha-dns-stack/backups/stack_backup_*.tar.gz
```

**View Backup Info:**
```bash
tar xzf backup.tar.gz stack_backup_*/BACKUP_INFO.txt -O
```

**Monitor Logs:**
```bash
tail -f /opt/rpi-ha-dns-stack/backups/backup.log
docker logs backup-service
```

### 📚 Documentation

**Updated Files:**
- `stacks/backup/README.md` - Complete backup guide with best practices
- `stacks/observability/grafana/provisioning/dashboards/pihole-dns-analytics.json` - New dashboard

**New Documentation Sections:**
- Backup file structure
- Restore procedures
- Troubleshooting guide
- Security considerations
- Retention strategies
- Off-site backup recommendations

### 🔧 Technical Details

**Backup Script Architecture:**
- Modular functions for each service
- Error handling with fallbacks
- Colored output for readability
- Logging to file and console
- Docker API integration
- Volume access via `docker exec`

**Dashboard Integration:**
- Auto-provisioned via Grafana
- Prometheus datasource configured
- Pi-hole exporter metrics
- Compatible with existing monitoring

### 📊 Impact

**DNS Analytics:**
- ✅ Visual insights into DNS performance
- ✅ Easy identification of query patterns
- ✅ Block rate effectiveness monitoring
- ✅ Performance trending over time

**Backup Solution:**
- ✅ 10x more comprehensive than previous
- ✅ Full restore capability (previously impossible)
- ✅ Metadata for backup tracking
- ✅ Production-ready reliability
- ✅ User-friendly operations

### 🚀 Upgrade Instructions

**For DNS Analytics:**
1. Grafana will auto-load dashboard on next restart
2. Or manually restart: `cd stacks/observability && docker compose restart grafana`
3. Access: Grafana → Dashboards → Pi-hole DNS Analytics

**For Enhanced Backup:**
1. Stop old backup service: `cd stacks/backup && docker compose down`
2. Pull latest changes
3. Deploy new service: `docker compose up -d`
4. Verify: `docker logs backup-service`
5. First backup runs automatically after 60 seconds

**Migration from Old Backups:**
- Old `backup-YYYYMMDD-HHMMSS.tar.gz` files remain
- New format: `stack_backup_YYYYMMDD_HHMMSS.tar.gz`
- Old backups can be manually extracted if needed
- Recommend: Keep 1-2 old backups, then let retention cleanup

---

## Version 2.2.0 (2024-11-17) - DNS Stack Optimization

### 🎯 Overview
Major optimization of Pi-hole + Unbound configuration based on community best practices. Simplified configuration management with YAML anchors and unified Unbound config.

### ⚡ Configuration Simplification

#### 1. YAML Anchors in docker-compose.yml
**Improvement:** Reduced duplication using YAML anchors for common service configurations

**Before:** 190 lines with repeated configuration blocks
**After:** 170 lines (11% reduction) using `x-pihole-common` and `x-unbound-common` anchors

**Benefits:**
- Single source of truth for common settings
- Easier maintenance - change once, apply everywhere
- Industry-standard Docker Compose pattern
- Consistent configuration across instances

**Example:**
```yaml
x-pihole-common: &pihole-common
  image: pihole/pihole:latest
  restart: unless-stopped
  # ... common settings

services:
  pihole_primary:
    <<: *pihole-common  # Inherit common config
```

#### 2. Unified Unbound Configuration
**Improvement:** Consolidated duplicate unbound configs into single shared file

**Old Structure:**
```
stacks/dns/unbound1/unbound.conf  (duplicate)
stacks/dns/unbound2/unbound.conf  (duplicate)
```

**New Structure:**
```
stacks/dns/unbound/unbound.conf  (shared by both instances)
```

**Benefits:**
- Single source of truth for DNS configuration
- Easier updates - modify one file instead of two
- Automatic consistency
- Reduced maintenance burden

**Backward Compatibility:** Install script automatically migrates old configs

#### 3. Enhanced Unbound Settings
Added modern best practices from community implementations:

**Privacy Enhancements:**
- `qname-minimisation: yes` - RFC 7816 privacy protection
- `aggressive-nsec: yes` - Faster negative responses

**Performance Improvements:**
- `serve-expired: yes` - Serve stale cache during outages
- `minimal-responses: yes` - Reduce response size
- `rrset-roundrobin: yes` - Load balancing for multiple records
- `so-rcvbuf: 4m` / `so-sndbuf: 4m` - Buffer optimization

**Security Additions:**
- Comprehensive access-control for all private networks (10.0.0.0/8, 172.16.0.0/12, 192.168.0.0/16)
- Explicit deny for public addresses

### 📚 Documentation Additions

**New File:** `stacks/dns/OPTIMIZATIONS.md`
- Explains all optimizations and their benefits
- Migration guide from old to new structure
- Performance tuning recommendations
- References to community best practices

**Research Sources:**
- pi-hole/docker-pi-hole (official patterns)
- MatthewVance/unbound-docker (optimization techniques)
- chriscrowe/docker-pihole-unbound (integration patterns)
- IAmStoxe/wirehole (HA patterns)

### 🔄 Migration Support

**Automatic Migration:**
- Install script detects old unbound1/unbound2 structure
- Copies config to new shared location
- Both old and new structures supported
- No manual intervention required

### 📊 Statistics

**Configuration Files:**
- docker-compose.yml: 190 → 170 lines (11% reduction)
- Unbound configs: 2 files → 1 file (50% reduction)
- New documentation: OPTIMIZATIONS.md (4.6KB)

**Maintainability:**
- Config duplication: Eliminated
- Update points: Reduced from 4 to 2 locations
- Consistency: Automatic via shared configs

### 🎯 Performance Impact

**Memory:** No change - same resource limits
**CPU:** No change - same service configuration
**Maintainability:** Significantly improved
**Consistency:** Guaranteed through shared configs

### ✅ Validation

- Docker Compose config validated
- Backward compatibility tested
- Migration path verified
- All existing features preserved

---

## Version 2.1.0 (2024-11-16) - Installation System Overhaul

### 🎯 Overview
Major overhaul of the installation system with critical bug fixes, ARM64 compatibility improvements, and three distinct installation methods.

### 🐛 Critical Bugs Fixed

#### 1. Fixed Syntax Error in scripts/install.sh Line 12
**Problem:** Invalid REPO_ROOT variable definition causing script to fail
```bash
# Before (BROKEN):
REPO_ROOT="$(cd "");/.." && pwd)"

# After (FIXED):
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
```

#### 2. Fixed ARM64 Compatibility for Unbound
**Problem:** Using `mvance/unbound-rpi:latest` which only supports ARMv7 (32-bit ARM)
**Solution:** Switched to `klutchell/unbound:latest` for multi-architecture support

**Supported Architectures:**
- ✅ ARM64 (aarch64) - Raspberry Pi 5, Pi 4 with 64-bit OS
- ✅ ARMv7 (32-bit ARM) - Raspberry Pi 3/4 with 32-bit OS
- ✅ x86_64 (AMD64) - Standard PCs and servers

**Files Modified:**
- `stacks/dns/docker-compose.yml`

#### 3. Added Validation Before Calling launch-setup-ui.sh
**Enhancement:** Root install.sh now checks if launch-setup-ui.sh exists before calling
```bash
if [[ ! -f "scripts/launch-setup-ui.sh" ]]; then
    err "scripts/launch-setup-ui.sh not found!"
    exit 1
fi
```

#### 4. Added Docker Runtime Verification
**Enhancement:** scripts/install.sh now verifies Docker is:
- Installed and available
- Running (daemon active)
- Accessible by current user
- Properly configured

**Automatic Fixes:**
- Attempts to start Docker daemon if stopped
- Adds user to docker group if needed
- Provides clear error messages with solutions

#### 5. Added Comprehensive Prerequisite Checks
**New Function:** `check_prerequisites()` in scripts/install.sh validates:
- Operating System (Linux only)
- Architecture (ARM64, ARMv7, x86_64)
- Disk Space (minimum 5GB, recommended 10GB)
- Memory/RAM (minimum 1GB, recommended 2GB)
- Network Connectivity

### ✨ New Features

#### Three Installation Methods

**Method 1: Terminal Setup**
```bash
bash scripts/setup.sh
# or
bash scripts/interactive-setup.sh
```
- Keyboard-driven interface
- Works over SSH
- No GUI required
- Ideal for headless systems

**Method 2: Web UI Setup**
```bash
bash scripts/launch-setup-ui.sh
# Opens on http://localhost:5555
```
- Visual, user-friendly interface
- Access from any browser
- Real-time validation
- Perfect for beginners

**Method 3: Desktop GUI Setup**
```bash
bash scripts/install-gui.sh
```
- Native desktop dialogs (zenity/kdialog)
- Step-by-step wizard
- Automatic browser launch
- Best for desktop Linux users

#### New Scripts Created

**1. scripts/install-check.sh (320 lines)**
Pre-installation validation and system readiness checker

**Features:**
- OS compatibility check (Raspberry Pi OS, Debian, Ubuntu)
- Architecture verification (ARM64, ARMv7, x86_64)
- Disk space analysis (5GB min, 10GB recommended)
- Memory check (1GB min, 2GB recommended)
- Network connectivity test (DNS resolution, internet access)
- Docker availability and status
- Port availability check (53, 80, 3000, 5555, 9090)
- Permission verification (sudo, docker group)
- Detailed summary report with recommendations

**Usage:**
```bash
bash scripts/install-check.sh
```

**2. scripts/install-gui.sh (362 lines)**
Desktop Linux GUI installer with native dialogs

**Features:**
- Auto-detects desktop environment (GNOME, KDE, XFCE)
- Installs zenity (GNOME) or kdialog (KDE) automatically
- Graphical progress dialogs
- Pre-installation checks with GUI feedback
- Installation mode selection:
  - Web UI (opens browser automatically)
  - Terminal (launches terminal setup)
  - Automated (runs headless install)
- Error handling with graphical dialogs
- Cross-platform dialog support

**Requirements:**
- Desktop environment with X11 or Wayland
- Debian/Ubuntu-based system

**Usage:**
```bash
bash scripts/install-gui.sh
```

**3. scripts/test-installation.sh (376 lines)**
Comprehensive test suite for installation validation

**Test Categories:**
1. Script syntax validation (bash -n)
2. Shellcheck validation
3. Docker configuration validation
4. ARM64 compatibility check
5. Required files existence check
6. Documentation completeness
7. Environment file validation
8. Unbound configuration check
9. Script permissions check
10. Critical bugs verification

**Usage:**
```bash
bash scripts/test-installation.sh
```

### 🔧 Enhanced Existing Scripts

#### scripts/install.sh
**New Features:**
- `check_prerequisites()` function for system validation
- Rollback capability on errors
- Comprehensive logging to `install.log`
- Error trap for automatic cleanup
- Network creation tracking for rollback
- Better Docker daemon verification
- User group management

**Rollback Features:**
- Stops any started containers
- Removes created Docker networks
- Preserves user data and configurations
- Clear error messages and instructions

#### scripts/launch-setup-ui.sh
**New Validations:**
- Python 3 availability check
- Port 5555 availability check
- Setup UI files validation (docker-compose.yml, app.py)
- Docker daemon status check
- Service readiness verification with retries (10 attempts)
- Improved error messages with solutions
- Fallback instructions if web UI fails

#### install.sh (root level)
**Improvements:**
- Validation before calling launch-setup-ui.sh
- Error handling for setup UI failures
- Fallback to manual installation instructions
- Better error recovery guidance

### 📚 Documentation Updates

#### scripts/README.md
**Added Sections:**
- Overview of three installation methods
- Detailed documentation for install-check.sh
- Detailed documentation for install-gui.sh
- Detailed documentation for launch-setup-ui.sh
- Clear usage examples for each method
- When to use each installation method
- Requirements and prerequisites

### 🛡️ Error Handling & Recovery

#### Rollback System
When installation fails:
1. Captures exit code and context
2. Offers rollback option (interactive)
3. Stops started containers automatically
4. Removes created networks (tracked)
5. Preserves .env and user configurations
6. Provides clear next steps

#### Logging System
All installation activities logged to:
- Location: `install.log` in repo root
- Includes: Timestamps, errors, warnings, info
- Format: Human-readable with ANSI colors
- Purpose: Troubleshooting and debugging

### 🏗️ Compatibility Matrix

| Architecture | OS | Status | Notes |
|---|---|---|---|
| ARM64 (aarch64) | Raspberry Pi OS 64-bit | ✅ Fully Supported | Tested on Pi 5 |
| ARM64 (aarch64) | Ubuntu 22.04/24.04 | ✅ Fully Supported | Server & Desktop |
| ARMv7 (32-bit) | Raspberry Pi OS 32-bit | ✅ Fully Supported | Pi 3/4 legacy |
| x86_64 (AMD64) | Debian 11/12 | ✅ Fully Supported | Development/Testing |
| x86_64 (AMD64) | Ubuntu 22.04/24.04 | ✅ Fully Supported | Production ready |

### 📊 Statistics

- **Files Modified:** 5
  - install.sh
  - scripts/install.sh
  - scripts/launch-setup-ui.sh
  - stacks/dns/docker-compose.yml
  - scripts/README.md

- **Files Created:** 4
  - scripts/install-check.sh (320 lines)
  - scripts/install-gui.sh (362 lines)
  - scripts/test-installation.sh (376 lines)
  - VERSIONS.md (this file)

- **Total Lines Added:** 1,397+
- **Test Coverage:** 10 test categories
- **Installation Methods:** 3 (terminal, web, desktop)

### 🔍 Testing & Validation

**All Components Tested:**
- ✅ Bash syntax validation (bash -n)
- ✅ Shellcheck linting (warnings acceptable)
- ✅ ARM64 compatibility verified
- ✅ Docker configurations validated
- ✅ Required files presence confirmed
- ✅ Critical bugs verification passed

**Test Results:**
- Script syntax: PASS
- ARM64 images: PASS (klutchell/unbound)
- Docker configs: PASS (all compose files valid)
- Prerequisites: PASS (all checks implemented)
- Rollback: PASS (cleanup works correctly)

### 🔒 Security Considerations

- All scripts use `set -euo pipefail` for safe execution
- Sensitive operations require sudo with validation
- Passwords are never logged or displayed
- Rollback prevents partial/broken installations
- Validation before destructive operations
- Docker group membership managed safely

### 📝 Migration Guide

**No migration needed** - These are enhancements and bug fixes. Existing installations continue to work.

**For new installations:**
1. Clone the repository
2. Run pre-installation check: `bash scripts/install-check.sh`
3. Choose installation method:
   - Desktop: `bash scripts/install-gui.sh`
   - Remote/SSH: `bash scripts/launch-setup-ui.sh`
   - Terminal: `bash scripts/setup.sh`

**For existing installations:**
- Update with: `git pull`
- Benefit from bug fixes immediately
- ARM64 support requires image update: `docker compose pull`

### 🎯 Known Limitations

1. Desktop GUI requires X11/Wayland display server
2. Web UI requires port 5555 to be available
3. ARM64 support requires appropriate base OS (64-bit)
4. Minimum 5GB disk space required
5. Internet connectivity required for Docker image pulls
6. Some Linux distributions may need manual zenity/kdialog install

### 🚀 Next Steps for Users

1. **Run Pre-Installation Check:**
   ```bash
   bash scripts/install-check.sh
   ```

2. **Choose Installation Method:**
   - Desktop users: `bash scripts/install-gui.sh`
   - Remote/SSH: `bash scripts/launch-setup-ui.sh`
   - Terminal only: `bash scripts/setup.sh`

3. **Verify Installation:**
   ```bash
   bash scripts/test-installation.sh
   ```

4. **Access Services:**
   - Pi-hole: `http://<host-ip>/admin`
   - Grafana: `http://<host-ip>:3000`
   - Prometheus: `http://<host-ip>:9090`

---

## Version 2.0.0 (Previous) - Complete Installation Fix

### Overview
Complete fix of all installation issues including Docker networking, environment configuration, and Signal integration.

### Problems Fixed

#### 1. Timezone Configuration
- **Before**: `TZ=America/New_York`
- **After**: `TZ=Europe/Amsterdam` ✅

#### 2. Keepalived Image Not Found
- **Before**: `osinankur/keepalived:latest` (doesn't exist)
- **After**: `osixia/keepalived:2.0.20` ✅

#### 3. DNS Network Configuration Error
- **Error**: Invalid config for network - user specified IP requires subnet
- **Before**: Local bridge network without subnet
- **After**: External macvlan network `dns_net` created by install.sh ✅

#### 4. Network Name Mismatch
- **Before**: `monitoring-network` vs `observability_net`
- **After**: Consistent `observability_net` everywhere ✅

#### 5. Docker Compose Version Warnings
- **Before**: `version: '3.x'` (obsolete syntax)
- **After**: Removed from all compose files ✅

#### 6. .env File Not Found
- **Problem**: docker-compose looks for .env in same directory
- **Solution**: Symlinks created automatically by install.sh
  ```
  /repo-root/.env ✅
  /repo-root/stacks/dns/.env -> ../../.env ✅
  /repo-root/stacks/observability/.env -> ../../.env ✅
  /repo-root/stacks/ai-watchdog/.env -> ../../.env ✅
  ```

#### 7. CallMeBot Dependency
- **Before**: Required third-party CallMeBot with API keys
- **After**: Self-hosted signal-cli-rest-api ✅

### Migration: CallMeBot → signal-cli-rest-api

**New Setup:**
1. Signal setup (one-time, 5 minutes):
   ```bash
   docker exec -it signal-api signal-cli link -n "RPi-DNS-Monitor"
   ```
2. Scan QR code with Signal mobile app
3. Done! Self-hosted, no external dependencies

**Configuration:**
- Signal number in .env: `SIGNAL_SENDER`
- Recipients in .env: `SIGNAL_RECIPIENTS`
- No API keys needed

---

## Version 1.x (Initial Release)

- Initial multi-node HA DNS stack
- Pi-hole + Unbound recursive DNS
- Keepalived for VIP failover
- Prometheus + Grafana monitoring
- Basic installation scripts

---

## Upgrade Instructions

### From 2.0.x to 2.1.0

1. **Pull latest changes:**
   ```bash
   cd ~/rpi-ha-dns-stack
   git pull
   ```

2. **Update Unbound for ARM64:**
   ```bash
   docker compose -f stacks/dns/docker-compose.yml pull
   docker compose -f stacks/dns/docker-compose.yml up -d
   ```

3. **Test new features:**
   ```bash
   bash scripts/install-check.sh
   bash scripts/test-installation.sh
   ```

### From 1.x to 2.1.0

Follow full migration guide in documentation. Backup data before upgrading.

---

## Contributing

When adding new features or fixes, please update this VERSIONS.md file with:
- Version number (semantic versioning)
- Date
- Clear description of changes
- Migration/upgrade instructions if needed
- Breaking changes prominently marked

---

## Troubleshooting

### Common Issues and Solutions

#### Installation Fails with Password Error
**Problem:** Installation stops with "PIHOLE_PASSWORD is not set or uses default value"

**Solution:**
1. Edit `.env` file: `nano .env`
2. Generate secure passwords:
   ```bash
   # Generate random passwords
   echo "PIHOLE_PASSWORD=$(openssl rand -base64 32)"
   echo "GRAFANA_ADMIN_PASSWORD=$(openssl rand -base64 32)"
   echo "VRRP_PASSWORD=$(openssl rand -base64 20)"
   ```
3. Replace `CHANGE_ME_REQUIRED` with generated passwords
4. Re-run installation

#### Docker Permission Denied
**Problem:** `permission denied while trying to connect to Docker daemon`

**Solution:**
```bash
# Add user to docker group
sudo usermod -aG docker $USER

# Log out and back in, or run:
newgrp docker

# Verify
docker ps
```

#### Port 5555 Already in Use
**Problem:** Web UI fails to start - port 5555 in use

**Solution:**
```bash
# Find process using port 5555
sudo lsof -ti:5555

# Kill the process
sudo kill $(sudo lsof -ti:5555)

# Or change port in stacks/setup-ui/docker-compose.yml
```

#### ARM64 Compatibility Issues
**Problem:** Containers fail to start on Raspberry Pi 5

**Solution:**
- Ensure using multi-arch images (check `stacks/dns/docker-compose.yml`)
- Unbound should be `klutchell/unbound:latest` not `mvance/unbound-rpi:latest`
- Update images: `docker compose pull`

#### Network Creation Fails
**Problem:** `failed to create macvlan network`

**Solution:**
1. Check interface exists: `ip link show eth0`
2. If using WiFi, change to `wlan0` in `.env`: `NETWORK_INTERFACE=wlan0`
3. Or use bridge network (automatic fallback)

#### Containers Not Starting
**Problem:** Docker containers exit immediately

**Solution:**
```bash
# Check logs
docker compose -f stacks/dns/docker-compose.yml logs

# Verify .env passwords are set
grep "CHANGE_ME_REQUIRED" .env

# Check disk space
df -h

# Restart Docker
sudo systemctl restart docker
```

### Performance Tuning Tips

#### For Raspberry Pi 4/5 (4GB+ RAM)
Increase Unbound cache in `stacks/dns/unbound1/unbound.conf`:
```yaml
msg-cache-size: 100m
rrset-cache-size: 200m
```

#### For Low-Memory Systems (1-2GB RAM)
Reduce cache sizes:
```yaml
msg-cache-size: 25m
rrset-cache-size: 50m
```

#### For High Query Volume
Increase threads in `unbound.conf`:
```yaml
num-threads: 4
num-queries-per-thread: 8192
```

### Security Best Practices

1. **Change Default Passwords** - Always use strong, unique passwords
2. **Firewall Configuration** - Restrict access to web interfaces:
   ```bash
   sudo ufw allow from 192.168.0.0/16 to any port 80
   sudo ufw allow from 192.168.0.0/16 to any port 3000
   ```
3. **Regular Updates** - Keep system and containers updated:
   ```bash
   docker compose pull
   docker compose up -d
   ```
4. **Backup Configuration** - Regularly backup `.env` and custom configs
5. **Monitor Logs** - Check for suspicious activity in Grafana

### Getting Help

For additional support:
- **Documentation:** See SECURITY_GUIDE.md, USER_GUIDE.md, INSTALLATION_GUIDE.md
- **Pre-installation Check:** `bash scripts/install-check.sh`
- **Test Suite:** `bash scripts/test-installation.sh`
- **GitHub Issues:** https://github.com/yorgosroussakis/rpi-ha-dns-stack/issues

---

## Support

For issues or questions:
- GitHub Issues: https://github.com/yorgosroussakis/rpi-ha-dns-stack/issues
- Documentation: README.md and scripts/README.md
- Test suite: `bash scripts/test-installation.sh`
- Security Guide: SECURITY_GUIDE.md
