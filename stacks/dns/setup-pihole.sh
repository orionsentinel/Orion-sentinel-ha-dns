#!/usr/bin/env bash
# Pi-hole Initial Configuration Script
# Sets up blocklists and whitelist for both Pi-hole instances
#
# Environment Variables:
#   PIHOLE_BLOCKLIST_PROFILE - Controls which blocklist set to use:
#     - standard (default): Balanced ad/malware/tracker blocking
#     - family: Standard + additional family-safe filtering
#     - paranoid: Maximum protection with aggressive blocking
#
# Usage:
#   PIHOLE_BLOCKLIST_PROFILE=standard bash setup-pihole.sh
#   PIHOLE_BLOCKLIST_PROFILE=paranoid bash setup-pihole.sh

set -euo pipefail

PIHOLE_PRIMARY="pihole_primary"
PIHOLE_SECONDARY="pihole_secondary"

# Blocklist profile from environment (default: standard)
PIHOLE_BLOCKLIST_PROFILE="${PIHOLE_BLOCKLIST_PROFILE:-standard}"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*"
}

# =============================================================================
# BLOCKLIST DEFINITIONS
# =============================================================================
# Core blocklists used in all profiles
declare -A BLOCKLIST_CORE=(
    ["Hagezi Pro++"]="https://cdn.jsdelivr.net/gh/hagezi/dns-blocklists@latest/wildcard/pro.plus.txt"
    ["OISD Big"]="https://big.oisd.nl/domainswild"
)

# Threat intelligence blocklists (standard+)
declare -A BLOCKLIST_THREAT=(
    ["Hagezi Threat Intelligence"]="https://cdn.jsdelivr.net/gh/hagezi/dns-blocklists@latest/wildcard/threat-intelligence.txt"
)

# Multi-purpose blocklists (family+)
declare -A BLOCKLIST_MULTI=(
    ["Hagezi Multi"]="https://cdn.jsdelivr.net/gh/hagezi/dns-blocklists@latest/wildcard/multi.txt"
)

# Additional blocklists for paranoid profile
declare -A BLOCKLIST_PARANOID=(
    ["Hagezi Ultimate"]="https://cdn.jsdelivr.net/gh/hagezi/dns-blocklists@latest/wildcard/ultimate.txt"
)

# Optional reference list (commented in docs, not installed by default)
# StevenBlack Unified: https://raw.githubusercontent.com/StevenBlack/hosts/master/hosts

# =============================================================================
# WHITELIST DEFINITIONS (Streaming & Common Services)
# =============================================================================
# Core streaming whitelist - domains that commonly break with blocklists
WHITELIST_STREAMING=(
    # Disney+
    "disneyplus.com"
    "disney-plus.net"
    "disneystreaming.com"
    "bamgrid.com"
    "dssott.com"
    "disney.com"
    "go.com"
    # Netflix
    "netflix.com"
    "nflxvideo.net"
    "nflximg.net"
    "nflxext.com"
    # Amazon Prime Video
    "amazon.com"
    "amazonvideo.com"
    "aiv-cdn.net"
    "aiv-delivery.net"
    # Hulu
    "hulu.com"
    "hulustream.com"
    "huluim.com"
    # HBO Max
    "hbomax.com"
    "hbo.com"
    # Apple TV+
    "apple.com"
    "tv.apple.com"
    "itunes.apple.com"
    # Spotify
    "spotify.com"
    "scdn.co"
    "spotifycdn.com"
    # YouTube (basic functionality)
    "youtube.com"
    "googlevideo.com"
    "ytimg.com"
)

# Additional whitelist entries as comments for manual addition if needed:
# - Plex: plex.tv, plex.direct
# - Roku: roku.com
# - Twitch: twitch.tv, twitchcdn.net
# - Peacock: peacocktv.com
# - Paramount+: paramountplus.com
# - ESPN: espn.com, espn.go.com
# - Crunchyroll: crunchyroll.com

# =============================================================================
# FUNCTIONS
# =============================================================================

# Escape single quotes for SQLite
escape_sql() {
    local input="$1"
    # Replace single quotes with two single quotes (SQLite escaping)
    printf '%s' "${input//\'/\'\'}"
}

# Check if a blocklist already exists in Pi-hole
blocklist_exists() {
    local container="$1"
    local url="$2"
    local escaped_url
    escaped_url=$(escape_sql "$url")
    local count
    count=$(docker exec "$container" bash -c "sqlite3 /etc/pihole/gravity.db \"SELECT COUNT(*) FROM adlist WHERE address='$escaped_url';\"" 2>/dev/null || echo "0")
    [[ "$count" -gt 0 ]]
}

# Add a blocklist (idempotent - skips if already present)
add_blocklist() {
    local container="$1"
    local name="$2"
    local url="$3"
    
    if blocklist_exists "$container" "$url"; then
        log "  [SKIP] $name already exists"
        return 0
    fi
    
    local escaped_url escaped_name
    escaped_url=$(escape_sql "$url")
    escaped_name=$(escape_sql "$name")
    
    log "  [ADD] $name"
    docker exec "$container" bash -c "sqlite3 /etc/pihole/gravity.db \"INSERT OR IGNORE INTO adlist (address, enabled, comment) VALUES ('$escaped_url', 1, '$escaped_name');\"" || {
        log "  [WARN] Failed to add $name"
        return 1
    }
}

# Check if domain is already whitelisted
domain_whitelisted() {
    local container="$1"
    local domain="$2"
    local escaped_domain
    escaped_domain=$(escape_sql "$domain")
    local count
    count=$(docker exec "$container" bash -c "sqlite3 /etc/pihole/gravity.db \"SELECT COUNT(*) FROM domainlist WHERE domain='$escaped_domain' AND type=0;\"" 2>/dev/null || echo "0")
    [[ "$count" -gt 0 ]]
}

# Add domain to whitelist (idempotent - skips if already present)
add_whitelist() {
    local container="$1"
    local domain="$2"
    
    if domain_whitelisted "$container" "$domain"; then
        log "    [SKIP] $domain already whitelisted"
        return 0
    fi
    
    log "    [ADD] $domain"
    docker exec "$container" pihole -w "$domain" &>/dev/null || {
        log "    [WARN] Failed to whitelist $domain"
        return 1
    }
}

# Configure Pi-hole with blocklists based on profile
configure_blocklists() {
    local container="$1"
    local profile="$2"
    
    log "Configuring blocklists for profile: $profile"
    
    # Core blocklists (all profiles)
    log "Adding core blocklists..."
    for name in "${!BLOCKLIST_CORE[@]}"; do
        add_blocklist "$container" "$name" "${BLOCKLIST_CORE[$name]}"
    done
    
    # Threat intelligence (standard, family, paranoid)
    if [[ "$profile" == "standard" || "$profile" == "family" || "$profile" == "paranoid" ]]; then
        log "Adding threat intelligence blocklists..."
        for name in "${!BLOCKLIST_THREAT[@]}"; do
            add_blocklist "$container" "$name" "${BLOCKLIST_THREAT[$name]}"
        done
    fi
    
    # Multi-purpose blocklists (family, paranoid)
    if [[ "$profile" == "family" || "$profile" == "paranoid" ]]; then
        log "Adding multi-purpose blocklists..."
        for name in "${!BLOCKLIST_MULTI[@]}"; do
            add_blocklist "$container" "$name" "${BLOCKLIST_MULTI[$name]}"
        done
    fi
    
    # Paranoid-only blocklists
    if [[ "$profile" == "paranoid" ]]; then
        log "Adding paranoid-level blocklists..."
        for name in "${!BLOCKLIST_PARANOID[@]}"; do
            add_blocklist "$container" "$name" "${BLOCKLIST_PARANOID[$name]}"
        done
    fi
}

# Configure whitelist for streaming services
configure_whitelist() {
    local container="$1"
    
    log "Configuring streaming service whitelist..."
    for domain in "${WHITELIST_STREAMING[@]}"; do
        add_whitelist "$container" "$domain"
    done
}

# Main configuration function for a single Pi-hole instance
configure_pihole() {
    local container="$1"
    local profile="$2"
    
    log "=========================================="
    log "Configuring $container (profile: $profile)"
    log "=========================================="
    
    # Add blocklists based on profile
    configure_blocklists "$container" "$profile"
    
    # Add streaming whitelist
    configure_whitelist "$container"
    
    # Update gravity database
    log "Updating gravity database (this may take a few minutes)..."
    docker exec "$container" pihole updateGravity || {
        log "WARNING: Gravity update had issues, but continuing..."
    }
    
    log "$container configured successfully!"
}

# Wait for containers to be ready
wait_for_container() {
    local container="$1"
    local max_wait=120
    local count=0
    
    log "Waiting for $container to be ready..."
    while ! docker exec "$container" pihole status &>/dev/null; do
        sleep 2
        count=$((count + 2))
        if [ $count -ge $max_wait ]; then
            log "ERROR: $container failed to become ready after ${max_wait}s"
            return 1
        fi
    done
    log "$container is ready!"
}

# Display profile information
show_profile_info() {
    local profile="$1"
    
    log ""
    log "=========================================="
    log "BLOCKLIST PROFILE: $profile"
    log "=========================================="
    
    case "$profile" in
        standard)
            log "Balanced ad/malware/tracker blocking"
            log "Includes: Hagezi Pro++, OISD Big, Hagezi Threat Intelligence"
            log "Estimated domains: ~4-5 million"
            ;;
        family)
            log "Family-safe with additional filtering"
            log "Includes: All standard + Hagezi Multi"
            log "Estimated domains: ~5-6 million"
            ;;
        paranoid)
            log "Maximum protection (may break some sites)"
            log "Includes: All family + Hagezi Ultimate"
            log "Estimated domains: ~7-8 million"
            ;;
        *)
            log "WARNING: Unknown profile '$profile', using 'standard'"
            ;;
    esac
    log ""
}

# Display verification steps
show_verification_steps() {
    log ""
    log "=========================================="
    log "VERIFICATION STEPS"
    log "=========================================="
    log ""
    log "1. Check Pi-hole status:"
    log "   docker exec pihole_primary pihole status"
    log ""
    log "2. Verify blocklist count:"
    log "   docker exec pihole_primary pihole -g -l"
    log ""
    log "3. Test DNS resolution (should resolve):"
    log "   dig @192.168.8.251 google.com +short"
    log ""
    log "4. Test ad blocking (should return 0.0.0.0 or NXDOMAIN):"
    log "   dig @192.168.8.251 ads.google.com +short"
    log ""
    log "5. Check gravity database stats:"
    log "   docker exec pihole_primary pihole -c -e"
    log ""
}

# =============================================================================
# MAIN
# =============================================================================
main() {
    log "Starting Pi-hole configuration..."
    
    # Validate profile
    case "$PIHOLE_BLOCKLIST_PROFILE" in
        standard|family|paranoid)
            ;;
        *)
            log "WARNING: Invalid PIHOLE_BLOCKLIST_PROFILE='$PIHOLE_BLOCKLIST_PROFILE'"
            log "Valid options: standard, family, paranoid"
            log "Defaulting to 'standard'"
            PIHOLE_BLOCKLIST_PROFILE="standard"
            ;;
    esac
    
    show_profile_info "$PIHOLE_BLOCKLIST_PROFILE"
    
    # Check if containers are running
    if ! docker ps --format '{{.Names}}' | grep -q "$PIHOLE_PRIMARY"; then
        log "ERROR: $PIHOLE_PRIMARY container not running"
        exit 1
    fi
    
    if ! docker ps --format '{{.Names}}' | grep -q "$PIHOLE_SECONDARY"; then
        log "WARNING: $PIHOLE_SECONDARY container not running, configuring primary only"
        
        # Wait and configure primary only
        wait_for_container "$PIHOLE_PRIMARY"
        configure_pihole "$PIHOLE_PRIMARY" "$PIHOLE_BLOCKLIST_PROFILE"
    else
        # Wait for both containers
        wait_for_container "$PIHOLE_PRIMARY"
        wait_for_container "$PIHOLE_SECONDARY"
        
        # Configure both Pi-hole instances
        configure_pihole "$PIHOLE_PRIMARY" "$PIHOLE_BLOCKLIST_PROFILE"
        configure_pihole "$PIHOLE_SECONDARY" "$PIHOLE_BLOCKLIST_PROFILE"
    fi
    
    log ""
    log "=========================================="
    log "Pi-hole configuration completed!"
    log "=========================================="
    log ""
    log "Profile applied: $PIHOLE_BLOCKLIST_PROFILE"
    log ""
    log "Blocklists added:"
    log "  - Hagezi Pro++ (https://cdn.jsdelivr.net/gh/hagezi/dns-blocklists@latest/wildcard/pro.plus.txt)"
    log "  - OISD Big (https://big.oisd.nl/domainswild)"
    log "  - Hagezi Threat Intelligence (https://cdn.jsdelivr.net/gh/hagezi/dns-blocklists@latest/wildcard/threat-intelligence.txt)"
    if [[ "$PIHOLE_BLOCKLIST_PROFILE" == "family" || "$PIHOLE_BLOCKLIST_PROFILE" == "paranoid" ]]; then
        log "  - Hagezi Multi (https://cdn.jsdelivr.net/gh/hagezi/dns-blocklists@latest/wildcard/multi.txt)"
    fi
    if [[ "$PIHOLE_BLOCKLIST_PROFILE" == "paranoid" ]]; then
        log "  - Hagezi Ultimate (https://cdn.jsdelivr.net/gh/hagezi/dns-blocklists@latest/wildcard/ultimate.txt)"
    fi
    log ""
    log "Optional (add manually if needed):"
    log "  # StevenBlack Unified: https://raw.githubusercontent.com/StevenBlack/hosts/master/hosts"
    log ""
    log "Whitelisted domains (streaming services):"
    log "  - Disney+: disneyplus.com, disney-plus.net, disneystreaming.com, bamgrid.com, dssott.com"
    log "  - Netflix: netflix.com, nflxvideo.net, nflximg.net"
    log "  - Amazon: amazon.com, amazonvideo.com"
    log "  - And more streaming services..."
    log ""
    log "To keep configurations in sync, run: bash pihole-sync.sh"
    
    show_verification_steps
}

main "$@"
