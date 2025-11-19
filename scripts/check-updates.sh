#!/usr/bin/env bash
# Automated Update Checker for Docker Images
# Checks Docker Hub and other registries for newer image versions

set -euo pipefail
IFS=$'\n\t'

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
UPDATE_REPORT="$REPO_ROOT/update-report.md"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

log() { echo -e "${GREEN}[check-updates]${NC} $*"; }
warn() { echo -e "${YELLOW}[WARNING]${NC} $*"; }
err() { echo -e "${RED}[ERROR]${NC} $*" >&2; }
info() { echo -e "${BLUE}[INFO]${NC} $*"; }

# Get latest tag from Docker Hub API
get_latest_tag_dockerhub() {
    local image=$1
    local repo="${image#*/}"  # Remove registry if present
    
    # Try to get latest tag from Docker Hub API
    local api_url="https://registry.hub.docker.com/v2/repositories/${repo}/tags?page_size=100"
    
    if command -v curl &> /dev/null; then
        curl -s "$api_url" | grep -Po '"name":"\K[^"]*' | grep -v "latest" | sort -V | tail -1
    else
        echo "unknown"
    fi
}

# Get current image digest
get_current_digest() {
    local image=$1
    docker images --digests --format "{{.Repository}}:{{.Tag}} {{.Digest}}" | grep "^${image}" | awk '{print $2}' | head -1
}

# Get remote image digest
get_remote_digest() {
    local image=$1
    docker pull "$image" &> /dev/null
    docker inspect "$image" --format='{{index .RepoDigests 0}}' 2>/dev/null | grep -oP 'sha256:[a-f0-9]+'
}

# Check if update is available
check_image_update() {
    local image=$1
    local current_digest=$(get_current_digest "$image")
    local remote_digest=$(get_remote_digest "$image")
    
    if [[ -z "$current_digest" ]]; then
        echo "not_installed"
    elif [[ "$current_digest" != "$remote_digest" ]]; then
        echo "update_available"
    else
        echo "up_to_date"
    fi
}

# Generate update report
generate_report() {
    log "Generating update report..."
    
    cat > "$UPDATE_REPORT" << 'EOF'
# Docker Image Update Report

Generated: $(date)

## Summary

This report shows the status of all Docker images used in the RPi HA DNS Stack.

## Image Status

| Image | Current Status | Latest Tag | Update Available |
|-------|---------------|------------|------------------|
EOF
    
    # Define all images used in the stack
    local images=(
        "pihole/pihole:latest"
        "klutchell/unbound:latest"
        "grafana/grafana:latest"
        "prom/prometheus:latest"
        "prom/alertmanager:latest"
        "grafana/loki:latest"
        "grafana/promtail:latest"
        "bbernhard/signal-cli-rest-api:latest"
        "portainer/portainer-ce:latest"
        "ghcr.io/gethomepage/homepage:latest"
        "louislam/uptime-kuma:latest"
        "netdata/netdata:latest"
        "containrrr/watchtower:latest"
        "linuxserver/wireguard:latest"
        "ngoduykhanh/wireguard-ui:latest"
        "jc21/nginx-proxy-manager:latest"
        "authelia/authelia:latest"
        "quay.io/oauth2-proxy/oauth2-proxy:latest"
        "cloudflare/cloudflared:latest"
        "tailscale/tailscale:latest"
        "redis:alpine"
        "alpine:latest"
        "nginx:alpine"
        "aquasec/trivy:latest"
    )
    
    local updates_available=0
    
    for image in "${images[@]}"; do
        info "Checking $image..."
        
        local status=$(check_image_update "$image")
        local latest_tag=$(get_latest_tag_dockerhub "$image" || echo "unknown")
        
        case $status in
            "update_available")
                echo "| $image | 🟡 Update Available | $latest_tag | Yes |" >> "$UPDATE_REPORT"
                ((updates_available++))
                ;;
            "up_to_date")
                echo "| $image | 🟢 Up to Date | $latest_tag | No |" >> "$UPDATE_REPORT"
                ;;
            "not_installed")
                echo "| $image | ⚪ Not Installed | $latest_tag | N/A |" >> "$UPDATE_REPORT"
                ;;
            *)
                echo "| $image | ❓ Unknown | $latest_tag | Unknown |" >> "$UPDATE_REPORT"
                ;;
        esac
    done
    
    cat >> "$UPDATE_REPORT" << EOF

## Recommendations

EOF
    
    if [[ $updates_available -gt 0 ]]; then
        cat >> "$UPDATE_REPORT" << 'EOF'
**Updates are available!**

To upgrade, run:
```bash
bash scripts/smart-upgrade.sh -u
```

Or to upgrade specific stacks:
```bash
# Upgrade DNS stack
bash scripts/smart-upgrade.sh -s dns

# Upgrade observability stack
bash scripts/smart-upgrade.sh -s observability
```

EOF
    else
        cat >> "$UPDATE_REPORT" << 'EOF'
**All images are up to date!**

No action required at this time.

EOF
    fi
    
    cat >> "$UPDATE_REPORT" << 'EOF'
## Automated Update Schedule

This check runs automatically:
- Daily at 3 AM (via cron)
- Manual: `bash scripts/check-updates.sh`

To enable automatic updates with Watchtower, see the management stack documentation.

---

**Note:** Always backup your configuration before upgrading. Use:
```bash
bash scripts/automated-backup.sh
```

EOF
    
    log "Update report generated: $UPDATE_REPORT"
    
    if [[ $updates_available -gt 0 ]]; then
        warn "$updates_available update(s) available"
        return 1
    else
        log "All images are up to date"
        return 0
    fi
}

# Main execution
main() {
    log "Starting update check..."
    echo
    
    if ! command -v docker &> /dev/null; then
        err "Docker is not installed"
        exit 1
    fi
    
    generate_report
    
    echo
    log "Check complete. Report saved to: $UPDATE_REPORT"
    
    # Display report
    if command -v bat &> /dev/null; then
        bat "$UPDATE_REPORT"
    elif command -v cat &> /dev/null; then
        cat "$UPDATE_REPORT"
    fi
}

main "$@"
