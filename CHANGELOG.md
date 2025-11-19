# Changelog

All notable changes to the RPi HA DNS Stack will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

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
