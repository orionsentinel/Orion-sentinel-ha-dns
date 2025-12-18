#!/usr/bin/env bash
# Orion Sentinel NetSec - Doctor Script
# Diagnostic tool for checking NetSec stack health
#
# Usage: ./scripts/doctor.sh

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Print functions
print_header() {
    echo -e "\n${BLUE}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${BLUE}  $1${NC}"
    echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
}

print_ok() {
    echo -e "${GREEN}✓${NC} $1"
}

print_warn() {
    echo -e "${YELLOW}⚠${NC} $1"
}

print_error() {
    echo -e "${RED}✗${NC} $1"
}

print_info() {
    echo -e "${BLUE}ℹ${NC} $1"
}

# ============================================================================
# Compose Project Name
# ============================================================================
print_header "Compose Project Name"

if [[ -f ".env" ]]; then
    PROJECT_NAME=$(grep -E "^COMPOSE_PROJECT_NAME=" .env 2>/dev/null | cut -d'=' -f2 || echo "")
    if [[ -n "$PROJECT_NAME" ]]; then
        print_ok "Project name: ${PROJECT_NAME}"
    else
        print_warn "COMPOSE_PROJECT_NAME not set in .env"
        print_info "Consider adding: COMPOSE_PROJECT_NAME=orion-netsec"
    fi
else
    print_warn ".env file not found"
    print_info "Copy .env.example to .env and configure"
fi

# Check for potential duplicate stacks
COMPOSE_CONTAINERS=$(docker ps --format '{{.Names}}' 2>/dev/null | grep -E "(suricata|evebox|netsec)" || true)
if [[ -n "$COMPOSE_CONTAINERS" ]]; then
    print_info "NetSec-related containers found: $(echo "$COMPOSE_CONTAINERS" | tr '\n' ' ')"
fi

# ============================================================================
# Running Containers and Ports
# ============================================================================
print_header "Running Containers and Ports"

# Define expected containers
EXPECTED_CONTAINERS=("suricata" "evebox" "cadvisor" "netsec_node_exporter" "netsec_promtail")

for container in "${EXPECTED_CONTAINERS[@]}"; do
    if docker ps --format '{{.Names}}' 2>/dev/null | grep -q "^${container}$"; then
        PORTS=$(docker port "$container" 2>/dev/null || echo "host networking / no exposed ports")
        print_ok "${container}: running"
        if [[ -n "$PORTS" && "$PORTS" != "host networking / no exposed ports" ]]; then
            echo "    Ports: $(echo "$PORTS" | tr '\n' ', ' | sed 's/, $//')"
        fi
    else
        print_warn "${container}: not running"
    fi
done

# Show port bindings summary
echo ""
print_info "Expected port bindings:"
echo "    node-exporter: 19100:9100"
echo "    cadvisor:      18080:8080"
echo "    evebox:        5636:5636"

# ============================================================================
# Suricata Health
# ============================================================================
print_header "Suricata Status"

if docker ps --format '{{.Names}}' 2>/dev/null | grep -q "^suricata$"; then
    print_ok "Suricata container is running"
    
    # Check for common errors in logs
    echo ""
    print_info "Checking for errors in Suricata logs..."
    
    # mmap errors
    MMAP_ERRORS=$(docker logs suricata 2>&1 | grep -i "mmap" | tail -3 || true)
    if [[ -n "$MMAP_ERRORS" ]]; then
        print_error "mmap errors detected:"
        echo "$MMAP_ERRORS" | head -3 | sed 's/^/    /'
    else
        print_ok "No mmap errors"
    fi
    
    # init socket errors
    SOCKET_ERRORS=$(docker logs suricata 2>&1 | grep -i "init socket" | tail -3 || true)
    if [[ -n "$SOCKET_ERRORS" ]]; then
        print_error "Socket initialization errors:"
        echo "$SOCKET_ERRORS" | head -3 | sed 's/^/    /'
    else
        print_ok "No socket errors"
    fi
    
    # no rules loaded
    RULE_ERRORS=$(docker logs suricata 2>&1 | grep -iE "(no rules|0 rules)" | tail -3 || true)
    if [[ -n "$RULE_ERRORS" ]]; then
        print_error "Rule loading issues:"
        echo "$RULE_ERRORS" | head -3 | sed 's/^/    /'
    else
        print_ok "No rule loading errors detected"
    fi
    
    # fanout errors
    FANOUT_ERRORS=$(docker logs suricata 2>&1 | grep -i "fanout" | tail -3 || true)
    if [[ -n "$FANOUT_ERRORS" ]]; then
        print_error "Fanout errors (should not occur with current config):"
        echo "$FANOUT_ERRORS" | head -3 | sed 's/^/    /'
    else
        print_ok "No fanout errors"
    fi
    
    # malformed integer
    MALFORMED_ERRORS=$(docker logs suricata 2>&1 | grep -i "malformed" | tail -3 || true)
    if [[ -n "$MALFORMED_ERRORS" ]]; then
        print_error "Malformed config errors:"
        echo "$MALFORMED_ERRORS" | head -3 | sed 's/^/    /'
    else
        print_ok "No malformed config errors"
    fi
    
else
    print_error "Suricata container is not running"
    print_info "Start with: docker compose --profile netsec-plus-evebox up -d"
fi

# ============================================================================
# Rule Load Status
# ============================================================================
print_header "Rule Load Status"

RULES_PATH="/mnt/orion-nvme-netsec/suricata/lib/rules/suricata.rules"

# Portable function to get file modification time in epoch seconds
get_file_mtime() {
    local file="$1"
    # Try Linux stat first, then macOS stat, then fallback to find
    if stat -c %Y "$file" 2>/dev/null; then
        return
    elif stat -f %m "$file" 2>/dev/null; then
        return
    else
        # Fallback using date command (works on most systems)
        date -r "$file" +%s 2>/dev/null || echo "0"
    fi
}

# Portable function to get file modification date (human readable)
get_file_date() {
    local file="$1"
    # Try Linux stat first, then macOS stat, then fallback to ls
    if stat -c %y "$file" 2>/dev/null | cut -d' ' -f1; then
        return
    elif stat -f %Sm -t %Y-%m-%d "$file" 2>/dev/null; then
        return
    else
        # Fallback using ls (works on most systems)
        ls -l "$file" 2>/dev/null | awk '{print $6, $7}' || echo "unknown"
    fi
}

if [[ -f "$RULES_PATH" ]]; then
    RULE_COUNT=$(grep -cE "^alert|^drop|^reject|^pass" "$RULES_PATH" 2>/dev/null || echo "0")
    RULES_SIZE=$(ls -lh "$RULES_PATH" 2>/dev/null | awk '{print $5}')
    RULES_DATE=$(get_file_date "$RULES_PATH")
    
    print_ok "Rules file exists: $RULES_PATH"
    print_info "Rule count: ~$RULE_COUNT active rules"
    print_info "File size: $RULES_SIZE"
    print_info "Last updated: $RULES_DATE"
else
    print_warn "Rules file not found at $RULES_PATH"
    print_info "Run: docker exec suricata suricata-update"
fi

# Check disable.conf
DISABLE_CONF="/mnt/orion-nvme-netsec/suricata/etc/disable.conf"
if [[ -f "$DISABLE_CONF" ]]; then
    DISABLED_COUNT=$(grep -cE "^[0-9]+" "$DISABLE_CONF" 2>/dev/null || echo "0")
    print_ok "Disable conf exists with $DISABLED_COUNT explicit SID disables"
else
    print_warn "disable.conf not found"
    print_info "Copy from: config/suricata/disable.conf"
fi

# ============================================================================
# Eve.json Growth Check
# ============================================================================
print_header "Eve.json Status"

EVE_PATH="/mnt/orion-nvme-netsec/suricata/logs/eve.json"

if [[ -f "$EVE_PATH" ]]; then
    EVE_SIZE=$(ls -lh "$EVE_PATH" 2>/dev/null | awk '{print $5}')
    EVE_MODIFIED=$(get_file_mtime "$EVE_PATH")
    # Ensure EVE_MODIFIED is a valid number
    if ! [[ "$EVE_MODIFIED" =~ ^[0-9]+$ ]]; then
        EVE_MODIFIED=0
    fi
    NOW=$(date +%s)
    AGE_SECONDS=$((NOW - EVE_MODIFIED))
    
    print_ok "eve.json exists"
    print_info "Size: $EVE_SIZE"
    
    if [[ $EVE_MODIFIED -eq 0 ]]; then
        print_warn "Could not determine last modification time"
    elif [[ $AGE_SECONDS -lt 60 ]]; then
        print_ok "Recently updated ($AGE_SECONDS seconds ago) - traffic flowing"
    elif [[ $AGE_SECONDS -lt 300 ]]; then
        print_warn "Updated $AGE_SECONDS seconds ago - low traffic or issue"
    else
        print_error "Last update over 5 minutes ago - possible capture issue"
    fi
    
    # Show last few events (with fallback if jq not available)
    echo ""
    print_info "Last 3 events:"
    if command -v jq &>/dev/null; then
        tail -3 "$EVE_PATH" 2>/dev/null | while read -r line; do
            EVENT_TYPE=$(echo "$line" | jq -r '.event_type // "unknown"' 2>/dev/null || echo "parse error")
            TIMESTAMP=$(echo "$line" | jq -r '.timestamp // "unknown"' 2>/dev/null || echo "parse error")
            echo "    [$TIMESTAMP] $EVENT_TYPE"
        done
    else
        print_info "(Install jq for detailed event parsing)"
        tail -3 "$EVE_PATH" 2>/dev/null | while read -r line; do
            # Basic parsing without jq - extract event_type using grep/sed
            EVENT_TYPE=$(echo "$line" | grep -oP '"event_type"\s*:\s*"\K[^"]+' 2>/dev/null || echo "json")
            echo "    [event] $EVENT_TYPE"
        done
    fi
else
    print_warn "eve.json not found at $EVE_PATH"
    print_info "Suricata may not have started logging yet"
fi

# ============================================================================
# Service Reachability
# ============================================================================
print_header "Service Reachability"

# Check node-exporter on 19100
if curl -sf --max-time 3 "http://localhost:19100/metrics" > /dev/null 2>&1; then
    print_ok "node-exporter reachable on port 19100"
else
    print_warn "node-exporter not reachable on port 19100"
fi

# Check cadvisor on 18080
if curl -sf --max-time 3 "http://localhost:18080/metrics" > /dev/null 2>&1; then
    print_ok "cadvisor reachable on port 18080"
else
    print_warn "cadvisor not reachable on port 18080"
fi

# Check evebox on 5636
if curl -sf --max-time 3 "http://localhost:5636/" > /dev/null 2>&1; then
    print_ok "EveBox reachable on port 5636"
else
    print_warn "EveBox not reachable on port 5636"
fi

# ============================================================================
# Summary
# ============================================================================
print_header "Summary"

# Count issues
ISSUES=0

if ! docker ps --format '{{.Names}}' 2>/dev/null | grep -q "^suricata$"; then
    ((ISSUES++))
fi
if ! docker ps --format '{{.Names}}' 2>/dev/null | grep -q "^evebox$"; then
    ((ISSUES++))
fi
if [[ ! -f "$RULES_PATH" ]]; then
    ((ISSUES++))
fi
if [[ ! -f "$EVE_PATH" ]]; then
    ((ISSUES++))
fi

if [[ $ISSUES -eq 0 ]]; then
    print_ok "All checks passed! NetSec stack appears healthy."
else
    print_warn "$ISSUES potential issue(s) detected. Review output above."
fi

echo ""
print_info "For detailed Suricata logs: docker logs suricata --tail 100"
print_info "For EveBox UI: http://localhost:5636"
print_info "Documentation: docs/netsec-node.md"
