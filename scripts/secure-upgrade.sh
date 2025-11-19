#!/usr/bin/env bash
# Security-Enhanced Upgrade System
# Integrates security scanning with the upgrade process

set -euo pipefail
IFS=$'\n\t'

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SECURITY_LOG="$REPO_ROOT/security-upgrade.log"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log() { echo -e "${GREEN}[security-upgrade]${NC} $*" | tee -a "$SECURITY_LOG"; }
warn() { echo -e "${YELLOW}[WARNING]${NC} $*" | tee -a "$SECURITY_LOG"; }
err() { echo -e "${RED}[ERROR]${NC} $*" >&2 | tee -a "$SECURITY_LOG"; }
info() { echo -e "${BLUE}[INFO]${NC} $*" | tee -a "$SECURITY_LOG"; }

# Initialize log
echo "=== Security-Enhanced Upgrade: $(date) ===" >> "$SECURITY_LOG"

# Check for security vulnerabilities before upgrade
pre_upgrade_security_scan() {
    log "Running pre-upgrade security scan..."
    
    local vulnerabilities_found=0
    
    # Check if Trivy is available
    if docker ps --format "{{.Names}}" | grep -q "trivy"; then
        info "Using Trivy for vulnerability scanning..."
        
        # Scan critical images
        local critical_images=(
            "pihole/pihole:latest"
            "klutchell/unbound:latest"
            "grafana/grafana:latest"
            "prom/prometheus:latest"
        )
        
        for image in "${critical_images[@]}"; do
            info "Scanning $image..."
            
            if docker run --rm \
                -v /var/run/docker.sock:/var/run/docker.sock \
                aquasec/trivy:latest image \
                --severity HIGH,CRITICAL \
                --quiet \
                "$image" 2>&1 | grep -q "Total: 0"; then
                echo "  ✓ No HIGH/CRITICAL vulnerabilities in $image"
            else
                warn "  ⚠ Vulnerabilities found in $image"
                ((vulnerabilities_found++))
            fi
        done
    else
        warn "Trivy not available - skipping vulnerability scan"
        info "To enable: cd stacks/management && docker compose up -d trivy"
    fi
    
    if [[ $vulnerabilities_found -gt 0 ]]; then
        warn "Found vulnerabilities in $vulnerabilities_found image(s)"
        warn "Consider reviewing security scan results before upgrade"
        echo
        read -r -p "Continue with upgrade anyway? (y/N): " choice
        [[ ! "$choice" =~ ^[Yy]$ ]] && exit 0
    else
        log "Pre-upgrade security scan passed"
    fi
    echo
}

# Verify image signatures (if enabled)
verify_image_signatures() {
    log "Checking image signature verification..."
    
    # Check if Docker Content Trust is enabled
    if [[ "${DOCKER_CONTENT_TRUST:-0}" == "1" ]]; then
        info "Docker Content Trust is enabled"
        log "Images will be verified during pull"
    else
        info "Docker Content Trust is not enabled"
        info "To enable: export DOCKER_CONTENT_TRUST=1"
        warn "Proceeding without signature verification"
    fi
    echo
}

# Check for known CVEs in running containers
check_running_containers() {
    log "Checking running containers for known vulnerabilities..."
    
    local containers=$(docker ps --format "{{.Names}}")
    local vulnerable_count=0
    
    for container in $containers; do
        # Get image of container
        local image=$(docker inspect "$container" --format='{{.Config.Image}}')
        
        # Quick CVE check (simplified)
        if docker run --rm \
            -v /var/run/docker.sock:/var/run/docker.sock \
            aquasec/trivy:latest image \
            --severity CRITICAL \
            --quiet \
            "$image" 2>&1 | grep -qi "CRITICAL"; then
            warn "Container '$container' has CRITICAL vulnerabilities"
            ((vulnerable_count++))
        fi
    done
    
    if [[ $vulnerable_count -gt 0 ]]; then
        warn "Found $vulnerable_count container(s) with CRITICAL vulnerabilities"
        info "Upgrade is recommended to patch these issues"
    else
        log "No CRITICAL vulnerabilities found in running containers"
    fi
    echo
}

# Generate security report
generate_security_report() {
    log "Generating security upgrade report..."
    
    local report_file="$REPO_ROOT/security-upgrade-report.md"
    
    cat > "$report_file" << 'EOF'
# Security-Enhanced Upgrade Report

Generated: $(date)

## Pre-Upgrade Security Status

### Container Vulnerability Scan

The following images were scanned for HIGH and CRITICAL vulnerabilities:

EOF
    
    # Add scan results
    docker run --rm \
        -v /var/run/docker.sock:/var/run/docker.sock \
        aquasec/trivy:latest image \
        --severity HIGH,CRITICAL \
        --format table \
        pihole/pihole:latest >> "$report_file" 2>/dev/null || echo "Scan failed" >> "$report_file"
    
    cat >> "$report_file" << 'EOF'

## Recommendations

### Security Best Practices for Upgrades

1. **Always backup before upgrading**: `bash scripts/automated-backup.sh`
2. **Review release notes**: Check for security fixes in new versions
3. **Test in staging**: If possible, test upgrades in non-production first
4. **Monitor after upgrade**: Watch logs for 24-48 hours post-upgrade
5. **Keep backups**: Retain backups for at least 7 days

### Security-Specific Steps

- ✅ Enable Docker Content Trust: `export DOCKER_CONTENT_TRUST=1`
- ✅ Use specific image tags instead of `:latest` for production
- ✅ Regular security scans: `bash scripts/security-scan.sh`
- ✅ Review CVE databases for your stack components
- ✅ Subscribe to security mailing lists for critical components

### Post-Upgrade Verification

After upgrading, verify:
- [ ] All containers started successfully
- [ ] No new vulnerabilities introduced
- [ ] Security configurations preserved
- [ ] Firewall rules still active
- [ ] TLS certificates valid
- [ ] Authentication working correctly

---

For questions, see: SECURITY_GUIDE.md
EOF
    
    log "Security report saved: $report_file"
    echo
}

# Main security-enhanced upgrade workflow
main() {
    log "Starting security-enhanced upgrade process..."
    echo
    
    # Run security checks
    verify_image_signatures
    pre_upgrade_security_scan
    check_running_containers
    generate_security_report
    
    # Call smart upgrade
    log "Security checks complete. Calling smart upgrade system..."
    echo
    
    if bash "$REPO_ROOT/scripts/smart-upgrade.sh" "$@"; then
        log "Upgrade completed successfully with security validation"
        
        # Post-upgrade security check
        log "Running post-upgrade security verification..."
        sleep 10
        
        # Verify no new vulnerabilities
        pre_upgrade_security_scan
        
        log "Security-enhanced upgrade complete! 🔒"
    else
        err "Upgrade failed or was cancelled"
        exit 1
    fi
}

# Show help
show_help() {
    cat << 'EOF'
Security-Enhanced Upgrade System

Adds security scanning and verification to the standard upgrade process.

Usage: bash scripts/secure-upgrade.sh [OPTIONS]

Options:
  -h, --help              Show this help message
  -i, --interactive       Interactive mode (passed to smart-upgrade.sh)
  -u, --upgrade           Perform full upgrade with security checks
  -c, --check             Check for updates and vulnerabilities
  --scan-only             Run security scan without upgrading

This script wraps smart-upgrade.sh with additional security checks:
  - Pre-upgrade vulnerability scanning
  - Image signature verification
  - Running container CVE checks
  - Security report generation
  - Post-upgrade security validation

Examples:
  # Full security-enhanced upgrade
  bash scripts/secure-upgrade.sh -u

  # Security scan only
  bash scripts/secure-upgrade.sh --scan-only

  # Interactive mode with security
  bash scripts/secure-upgrade.sh -i

EOF
}

# Parse arguments
if [[ $# -eq 0 ]]; then
    main
elif [[ "$1" == "-h" || "$1" == "--help" ]]; then
    show_help
elif [[ "$1" == "--scan-only" ]]; then
    verify_image_signatures
    pre_upgrade_security_scan
    check_running_containers
    generate_security_report
else
    main "$@"
fi
