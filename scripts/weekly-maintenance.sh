#!/bin/bash
# Weekly Maintenance Script for RPi HA DNS Stack
# Automates routine maintenance tasks

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TIMESTAMP=$(date '+%Y-%m-%d_%H-%M-%S')
BACKUP_DIR="/opt/rpi-dns-backups"
LOG_FILE="/var/log/rpi-dns-maintenance.log"

echo "=========================================="
echo "RPi HA DNS Stack Weekly Maintenance"
echo "Time: $(date '+%Y-%m-%d %H:%M:%S')"
echo "=========================================="

# Step 1: Update Container Images
echo ""
echo "Step 1: Updating container images..."
cd /opt/rpi-ha-dns-stack || exit 1

# Pull latest images for all stacks
for stack_dir in stacks/*/; do
    if [ -f "${stack_dir}docker-compose.yml" ]; then
        stack_name=$(basename "$stack_dir")
        echo "  Pulling images for $stack_name..."
        (cd "$stack_dir" && docker compose pull) || echo "  ⚠️  Failed to pull for $stack_name"
    fi
done

# Step 2: Clean Up Old Logs
echo ""
echo "Step 2: Cleaning old logs..."
find /var/log/pihole -name "*.log.*" -mtime +30 -delete 2>/dev/null || true
find /var/lib/docker/containers -name "*-json.log*" -mtime +30 -delete 2>/dev/null || true
echo "✅ Old logs cleaned"

# Step 3: Check Disk Space
echo ""
echo "Step 3: Checking disk space..."
df -h / /var | grep -E '^Filesystem|^/dev'

DISK_USAGE=$(df / | awk 'NR==2 {print $5}' | sed 's/%//')
if [ "$DISK_USAGE" -gt 80 ]; then
    echo "⚠️  WARNING: Disk usage is ${DISK_USAGE}%"
    # Clean Docker system
    echo "  Running Docker cleanup..."
    docker system prune -f
fi

# Step 4: Backup Configuration
echo ""
echo "Step 4: Backing up configuration..."
mkdir -p "$BACKUP_DIR"

# Backup .env files
for env_file in $(find /opt/rpi-ha-dns-stack -name ".env" -type f); do
    relative_path=$(echo "$env_file" | sed 's|/opt/rpi-ha-dns-stack/||')
    backup_path="$BACKUP_DIR/env-backups/$TIMESTAMP/$(dirname $relative_path)"
    mkdir -p "$backup_path"
    cp "$env_file" "$backup_path/"
done

# Backup docker-compose files
for compose_file in $(find /opt/rpi-ha-dns-stack -name "docker-compose.yml" -type f); do
    relative_path=$(echo "$compose_file" | sed 's|/opt/rpi-ha-dns-stack/||')
    backup_path="$BACKUP_DIR/compose-backups/$TIMESTAMP/$(dirname $relative_path)"
    mkdir -p "$backup_path"
    cp "$compose_file" "$backup_path/"
done

echo "✅ Configuration backed up to $BACKUP_DIR/$TIMESTAMP"

# Remove backups older than 90 days
find "$BACKUP_DIR" -type d -mtime +90 -exec rm -rf {} + 2>/dev/null || true

# Step 5: Container Statistics
echo ""
echo "Step 5: Container resource usage..."
docker stats --no-stream --format "table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}"

# Step 6: Check for Updates
echo ""
echo "Step 6: Checking for available updates..."
OUTDATED=$(docker images --filter "dangling=false" --format "{{.Repository}}:{{.Tag}}" | \
    xargs -I {} docker manifest inspect {} > /dev/null 2>&1 || echo "available")

if [ -n "$OUTDATED" ]; then
    echo "ℹ️  Container updates are available. Review with 'docker images'"
else
    echo "✅ All containers up to date"
fi

# Step 7: Generate Report
echo ""
echo "Step 7: Generating health report..."

REPORT_FILE="$BACKUP_DIR/reports/health-report-$TIMESTAMP.txt"
mkdir -p "$BACKUP_DIR/reports"

{
    echo "=========================================="
    echo "RPi HA DNS Stack Health Report"
    echo "Generated: $(date)"
    echo "=========================================="
    echo ""
    
    echo "SYSTEM INFO:"
    echo "  Hostname: $(hostname)"
    echo "  Uptime: $(uptime -p)"
    echo "  Load Average: $(uptime | awk -F'load average:' '{print $2}')"
    echo ""
    
    echo "DISK USAGE:"
    df -h / /var | grep -E '^Filesystem|^/dev'
    echo ""
    
    echo "MEMORY USAGE:"
    free -h
    echo ""
    
    echo "RUNNING CONTAINERS:"
    docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Image}}"
    echo ""
    
    echo "DNS RESOLUTION TEST:"
    dig @192.168.8.255 google.com +short || echo "FAILED"
    echo ""
    
} > "$REPORT_FILE"

echo "✅ Report saved to $REPORT_FILE"

# Optional: Email report (if configured)
# if command -v mail &> /dev/null; then
#     mail -s "RPi DNS Weekly Report" admin@example.com < "$REPORT_FILE"
# fi

# Summary
echo ""
echo "=========================================="
echo "Maintenance Complete"
echo "=========================================="
echo ""
echo "To run this automatically:"
echo "  sudo crontab -e"
echo "  Add: 0 3 * * 0 /opt/rpi-ha-dns-stack/scripts/weekly-maintenance.sh >> /var/log/rpi-dns-maintenance.log 2>&1"
echo ""
