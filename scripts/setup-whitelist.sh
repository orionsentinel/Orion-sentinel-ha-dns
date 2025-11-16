#!/usr/bin/env bash
# Essential Whitelists for Common Services
# Prevents common services from breaking due to Pi-hole blocking

set -euo pipefail

CONTAINER="${1:-pihole_primary}"

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

log() { echo -e "${GREEN}[✓]${NC} $*"; }
info() { echo -e "${BLUE}[i]${NC} $*"; }

# Check if container exists
if ! docker ps --format '{{.Names}}' | grep -q "^${CONTAINER}$"; then
    echo "Error: Container '$CONTAINER' not found or not running"
    exit 1
fi

echo ""
echo "═══════════════════════════════════════════"
echo " Essential Whitelist Setup"
echo "═══════════════════════════════════════════"
echo ""

info "Adding streaming service domains..."
docker exec "$CONTAINER" pihole -w \
    disneyplus.com disney-plus.net disneystreaming.com bamgrid.com dssott.com \
    netflix.com nflxext.com nflximg.net nflxso.net nflxvideo.net \
    amazon.com amazonaws.com \
    hulu.com hulustream.com \
    hbomax.com hbomaxcdn.com \
    apple.com itunes.com \
    > /dev/null 2>&1
log "Streaming services whitelisted"

info "Adding smart home device domains..."
docker exec "$CONTAINER" pihole -w \
    device-metrics-us.amazon.com device-metrics-us-2.amazon.com \
    clients4.google.com clients6.google.com \
    roku.com \
    samsungcloudsolution.com samsungelectronics.com \
    > /dev/null 2>&1
log "Smart home devices whitelisted"

info "Adding Microsoft service domains..."
docker exec "$CONTAINER" pihole -w \
    windowsupdate.com update.microsoft.com \
    office.com office365.com outlook.com \
    xbox.com xboxlive.com \
    > /dev/null 2>&1
log "Microsoft services whitelisted"

info "Adding CDN and essential infrastructure..."
docker exec "$CONTAINER" pihole -w \
    googleapis.com gstatic.com \
    cloudflare.com cloudflaressl.com \
    akamaihd.net \
    > /dev/null 2>&1
log "CDN domains whitelisted"

echo ""
log "Essential whitelists configured!"
echo ""

# Show whitelist count
WHITELIST_COUNT=$(docker exec "$CONTAINER" bash -c \
    "sqlite3 /etc/pihole/gravity.db 'SELECT COUNT(*) FROM domainlist WHERE type=0;'" 2>/dev/null || echo "unknown")

info "Total whitelisted domains: $WHITELIST_COUNT"
echo ""
info "To add more domains: docker exec $CONTAINER pihole -w example.com"
info "To remove domain: docker exec $CONTAINER pihole -w -d example.com"
echo ""
