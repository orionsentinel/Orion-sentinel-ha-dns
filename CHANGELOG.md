# Changelog

All notable changes to the RPi HA DNS Stack will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added - v2.4.0 Smart Upgrade System (2024-11-19) 🚀
- **Smart Upgrade System** (`scripts/smart-upgrade.sh`) - Intelligent upgrade management
  - Interactive menu interface for upgrade operations
  - Pre-upgrade health checks (disk space, Docker status, network connectivity)
  - Automatic backup creation before any upgrade
  - Selective stack upgrades (upgrade all or individual stacks)
  - Post-upgrade verification (container health, DNS resolution tests)
  - Comprehensive logging to `upgrade.log`
  - Rollback capability via backup restore
  - 8 command-line options for flexibility
- **Automated Update Checker** (`scripts/check-updates.sh`) - Docker image monitoring
  - Scans 24+ Docker images for available updates
  - Compares current vs. latest image digests
  - Generates detailed `update-report.md` with status indicators
  - Integrates with Docker Hub API for version information
  - Provides specific upgrade recommendations
  - Can be scheduled via cron for daily checks
- **Security-Enhanced Upgrade** (`scripts/secure-upgrade.sh`) - Security-first upgrades
  - Pre-upgrade vulnerability scanning with Trivy
  - Docker Content Trust verification support
  - CVE checks for running containers
  - Security report generation
  - Post-upgrade security validation
- **Comprehensive Documentation**
  - `SMART_UPGRADE_GUIDE.md` - Complete 500+ line usage guide with examples
  - Enhanced `VERSIONS.md` with v2.4.0 release notes
  - Updated `README.md` with smart upgrade section
  - Updated `scripts/README.md` with new script documentation
- **Version Tracking System**
  - Template for `.versions.yml` for version management
  - Tracks all service images and their versions
  - Auto-update flags per service
  - Stack version tracking and upgrade notes

### Changed
- **Upgrade Process** - Enhanced from manual to automated with safety checks
  - Before: Manual `git pull && docker compose pull && up -d`
  - After: Automated `smart-upgrade.sh -u` with comprehensive validation
- **Update Notifications** - Now automated with daily check capability
  - Before: No notification of available updates
  - After: Optional automated daily update reports

### Security
- Added pre-upgrade security vulnerability scanning
- Added image signature verification support (Docker Content Trust)
- Added CVE checking for running containers
- Added security report generation for upgrade auditing

### Impact on Users
- **Safer Upgrades**: Pre/post validation reduces risk of failed upgrades
- **Easier Maintenance**: One command for checking and applying updates
- **Better Visibility**: Know exactly what versions are running and what's available
- **Quick Recovery**: One-click rollback via integrated backup system
- **Peace of Mind**: Comprehensive health checks before and after upgrades

### Migration Steps
No migration required - this is a backward-compatible feature addition.

To start using the new system:
```bash
# Make scripts executable
chmod +x scripts/smart-upgrade.sh scripts/check-updates.sh scripts/secure-upgrade.sh

# Try interactive mode
bash scripts/smart-upgrade.sh -i

# Or check for updates
bash scripts/smart-upgrade.sh -c
```

Existing upgrade methods (`scripts/update.sh`) continue to work as before.

---

## [Previous Unreleased]

### Added
- Operational excellence scripts (`health-check.sh`, `weekly-maintenance.sh`)
- Operational runbook for common issues and procedures
- Disaster recovery plan with detailed recovery procedures
- Automated health checks and maintenance procedures

### Removed
- Intrusion detection stack (determined to be overhead for home use case)
- Complexity in favor of operational maturity

## [1.0.0] - YYYY-MM-DD

### Added
- Initial release with HA DNS stack
- Dual Pi-hole setup with Unbound
- Keepalived for high availability
- Prometheus + Grafana monitoring
- SSO with Authelia
- Multi-node deployment options

---

## How to Use This Changelog

### For Maintainers

When making changes:
1. Add entry under `[Unreleased]` section
2. Use appropriate category:
   - `Added` for new features
   - `Changed` for changes in existing functionality
   - `Deprecated` for soon-to-be removed features
   - `Removed` for now removed features
   - `Fixed` for any bug fixes
   - `Security` for security updates

3. Include:
   - What changed
   - Why it changed
   - Impact on users
   - Migration steps (if needed)

Example entry:
```markdown
### Changed
- Updated Pi-hole to version 6.0
  - **Why**: Security patches and new features
  - **Impact**: Requires manual update of custom blocklists
  - **Migration**: Run `docker exec pihole_primary pihole -up`
```

### For Users

- Check `[Unreleased]` for upcoming changes
- Review version sections for changes in your deployment
- Follow migration guides for breaking changes

---

## Change Template

```markdown
## [Version] - YYYY-MM-DD

### Added
- Feature 1 - Description and reason
- Feature 2 - Description and reason

### Changed
- Component X - What changed and why
  - **Impact**: Description
  - **Migration**: Steps if needed

### Fixed
- Bug fix description
- Root cause and resolution

### Removed
- Feature/service removed
  - **Reason**: Why it was removed
  - **Alternative**: What to use instead
```

---

**Maintenance**: Update this file with every significant change. Review quarterly for accuracy.
