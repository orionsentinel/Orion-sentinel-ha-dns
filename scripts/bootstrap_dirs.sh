#!/usr/bin/env bash
# bootstrap_dirs.sh - Create necessary directories and files for Orion Sentinel HA DNS
# 
# This script ensures all required directories exist and that log files are
# created as files (not directories) to prevent "Is a directory" errors.
#
# Run this script after cloning the repo and before starting docker compose.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(dirname "$SCRIPT_DIR")"

echo "Bootstrapping directories for Orion Sentinel HA DNS..."

# Create pihole directories
mkdir -p "$REPO_DIR/pihole/etc-pihole"
mkdir -p "$REPO_DIR/pihole/etc-dnsmasq.d"
mkdir -p "$REPO_DIR/pihole/var-log"

# Create pihole.log as a file (not a directory)
# This prevents "dnsmasq: cannot open log /var/log/pihole/pihole.log: Is a directory"
if [ -d "$REPO_DIR/pihole/var-log/pihole.log" ]; then
    echo "Warning: pihole.log exists as a directory. Removing it..."
    rm -rf "$REPO_DIR/pihole/var-log/pihole.log"
fi
touch "$REPO_DIR/pihole/var-log/pihole.log"

# Create keepalived config directory
mkdir -p "$REPO_DIR/keepalived/config"

# Ensure .gitkeep files exist for empty directories
for dir in "pihole/etc-pihole" "pihole/etc-dnsmasq.d" "keepalived/config"; do
    if [ -d "$REPO_DIR/$dir" ] && [ ! -f "$REPO_DIR/$dir/.gitkeep" ]; then
        touch "$REPO_DIR/$dir/.gitkeep"
    fi
done

echo "✓ Directories bootstrapped successfully"
echo ""
echo "Created/verified:"
echo "  - pihole/etc-pihole/"
echo "  - pihole/etc-dnsmasq.d/"
echo "  - pihole/var-log/"
echo "  - pihole/var-log/pihole.log (as file)"
echo "  - keepalived/config/"
echo ""
echo "You can now run: docker compose --profile <profile> up -d"
