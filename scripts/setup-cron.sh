#!/bin/bash
# Setup Cron Jobs for RPi HA DNS Stack
# Automatically configures weekly health checks and maintenance

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log() { echo -e "${GREEN}[cron-setup]${NC} $*"; }
warn() { echo -e "${YELLOW}[cron-setup][WARNING]${NC} $*"; }
err() { echo -e "${RED}[cron-setup][ERROR]${NC} $*" >&2; }
info() { echo -e "${BLUE}[cron-setup][INFO]${NC} $*"; }

echo "=========================================="
echo "RPi HA DNS Stack - Cron Job Setup"
echo "=========================================="
echo ""

# Check if running as root or with sudo
if [[ $EUID -ne 0 ]]; then
    warn "This script needs sudo to modify crontab"
    echo "Re-running with sudo..."
    exec sudo bash "$0" "$@"
fi

# Get the actual user (in case running via sudo)
ACTUAL_USER="${SUDO_USER:-$USER}"
ACTUAL_HOME=$(getent passwd "$ACTUAL_USER" | cut -d: -f6)

log "Setting up cron jobs for user: $ACTUAL_USER"

# Create log directory
LOG_DIR="/var/log/rpi-dns"
if [ ! -d "$LOG_DIR" ]; then
    mkdir -p "$LOG_DIR"
    chown "$ACTUAL_USER:$ACTUAL_USER" "$LOG_DIR"
    log "Created log directory: $LOG_DIR"
fi

# Backup existing crontab
BACKUP_FILE="${ACTUAL_HOME}/.crontab.backup.$(date +%Y%m%d_%H%M%S)"
crontab -u "$ACTUAL_USER" -l > "$BACKUP_FILE" 2>/dev/null || touch "$BACKUP_FILE"
log "Backed up existing crontab to: $BACKUP_FILE"

# Create temporary file for new crontab
TEMP_CRON=$(mktemp)

# Copy existing crontab (excluding our old entries if any)
crontab -u "$ACTUAL_USER" -l 2>/dev/null | \
    grep -v "rpi-dns-health-check" | \
    grep -v "rpi-dns-maintenance" | \
    grep -v "# RPi HA DNS Stack automation" \
    > "$TEMP_CRON" || true

# Add header
cat >> "$TEMP_CRON" << EOF

# RPi HA DNS Stack automation
# Added by setup-cron.sh on $(date)

EOF

# Add health check job (Sundays at 2 AM)
cat >> "$TEMP_CRON" << EOF
# Weekly health check (Sundays at 2 AM)
0 2 * * 0 ${REPO_ROOT}/scripts/health-check.sh >> ${LOG_DIR}/health-check.log 2>&1

EOF

# Add weekly maintenance job (Sundays at 3 AM)
cat >> "$TEMP_CRON" << EOF
# Weekly maintenance (Sundays at 3 AM)
0 3 * * 0 ${REPO_ROOT}/scripts/weekly-maintenance.sh >> ${LOG_DIR}/maintenance.log 2>&1

EOF

# Install new crontab
crontab -u "$ACTUAL_USER" "$TEMP_CRON"
rm "$TEMP_CRON"

echo ""
log "✅ Cron jobs installed successfully!"
echo ""

# Display installed cron jobs
echo "Installed cron jobs:"
echo "─────────────────────────────────────────"
crontab -u "$ACTUAL_USER" -l | grep -A 1 "RPi HA DNS Stack"
echo "─────────────────────────────────────────"
echo ""

# Verify scripts are executable
if [ ! -x "${REPO_ROOT}/scripts/health-check.sh" ]; then
    chmod +x "${REPO_ROOT}/scripts/health-check.sh"
    log "Made health-check.sh executable"
fi

if [ ! -x "${REPO_ROOT}/scripts/weekly-maintenance.sh" ]; then
    chmod +x "${REPO_ROOT}/scripts/weekly-maintenance.sh"
    log "Made weekly-maintenance.sh executable"
fi

# Create log rotation config
LOGROTATE_CONF="/etc/logrotate.d/rpi-dns"
if [ ! -f "$LOGROTATE_CONF" ]; then
    info "Setting up log rotation..."
    cat > "$LOGROTATE_CONF" << 'EOF'
/var/log/rpi-dns/*.log {
    weekly
    rotate 12
    compress
    delaycompress
    missingok
    notifempty
    create 0644 root root
}
EOF
    log "Created log rotation config: $LOGROTATE_CONF"
fi

echo ""
echo "=========================================="
echo "Setup Complete!"
echo "=========================================="
echo ""
echo "📅 Schedule:"
echo "  - Health checks: Sundays at 2:00 AM"
echo "  - Maintenance: Sundays at 3:00 AM"
echo ""
echo "📁 Logs location:"
echo "  - ${LOG_DIR}/health-check.log"
echo "  - ${LOG_DIR}/maintenance.log"
echo ""
echo "🔧 Manual execution:"
echo "  - Health check: bash ${REPO_ROOT}/scripts/health-check.sh"
echo "  - Maintenance: bash ${REPO_ROOT}/scripts/weekly-maintenance.sh"
echo ""
echo "📋 View cron jobs: crontab -l"
echo "📝 Edit cron jobs: crontab -e"
echo ""
echo "💾 Crontab backup saved to: $BACKUP_FILE"
echo ""
