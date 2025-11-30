#!/usr/bin/env bash
# Validate .env file for required variables and secure passwords
# This script checks for:
# - Required variables are present (based on DEPLOYMENT_MODE)
# - Passwords are not default/weak values
# - IP addresses are valid and in correct subnet
# - VIP is not network/broadcast address
# - Proper formatting of KEY=VALUE pairs

set -o pipefail
IFS=$'\n\t'

REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || (cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd))"
ENV_FILE="$REPO_ROOT/.env"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log() { echo -e "${GREEN}[✓]${NC} $*"; }
warn() { echo -e "${YELLOW}[!]${NC} $*"; }
err() { echo -e "${RED}[✗]${NC} $*" >&2; }

VALIDATION_ERRORS=0
VALIDATION_WARNINGS=0

# Check if .env file exists
if [[ ! -f "$ENV_FILE" ]]; then
    err ".env file not found at $ENV_FILE"
    err "Please create one from env/.env.two-pi-ha.example or .env.example:"
    err "  cp env/.env.two-pi-ha.example .env"
    exit 1
fi

log "Validating $ENV_FILE"
echo ""

# Load environment variables (strip inline comments for sourcing)
# Create a temporary file without inline comments
TEMP_ENV=$(mktemp)
trap "rm -f $TEMP_ENV" EXIT

# Strip inline comments for safe sourcing
while IFS= read -r line; do
    # Skip full-line comments and empty lines
    [[ -z "$line" || "$line" =~ ^[[:space:]]*# ]] && continue
    
    # Strip inline comments but preserve the KEY=VALUE part
    if [[ "$line" =~ ^([^#]+) ]]; then
        echo "${BASH_REMATCH[1]}" >> "$TEMP_ENV"
    fi
done < "$ENV_FILE"

set -a
# shellcheck disable=SC1090
source "$TEMP_ENV" 2>/dev/null || {
    warn "Could not source .env file completely - some variables may be complex"
}
set +a

# Detect deployment mode
DEPLOYMENT_MODE="${DEPLOYMENT_MODE:-}"
if [[ -z "$DEPLOYMENT_MODE" ]]; then
    # Try to infer from other variables
    if [[ -n "${PI1_IP:-}" ]] && [[ -n "${PI2_IP:-}" ]]; then
        DEPLOYMENT_MODE="two-pi-ha"
    elif [[ -n "${HOST_IP:-}" ]]; then
        DEPLOYMENT_MODE="single-pi"
    fi
fi

echo "Detected deployment mode: ${DEPLOYMENT_MODE:-unknown}"
echo ""

# Define required variables based on deployment mode
case "${DEPLOYMENT_MODE:-}" in
    two-pi-ha)
        REQUIRED_VARS=(
            "HOST_IP"
            "PI1_IP"
            "PI2_IP"
            "VIP_ADDRESS"
            "NETWORK_INTERFACE"
            "SUBNET"
            "GATEWAY"
            "TZ"
            "PIHOLE_PASSWORD"
            "GRAFANA_ADMIN_USER"
            "GRAFANA_ADMIN_PASSWORD"
            "VRRP_PASSWORD"
        )
        ;;
    single-pi-ha)
        REQUIRED_VARS=(
            "HOST_IP"
            "VIP_ADDRESS"
            "NETWORK_INTERFACE"
            "SUBNET"
            "GATEWAY"
            "TZ"
            "PIHOLE_PASSWORD"
            "GRAFANA_ADMIN_PASSWORD"
            "VRRP_PASSWORD"
        )
        ;;
    two-pi-simple|single-pi|*)
        # Fallback: require common variables
        REQUIRED_VARS=(
            "NETWORK_INTERFACE"
            "SUBNET"
            "GATEWAY"
            "TZ"
            "PIHOLE_PASSWORD"
        )
        # For two-pi-simple or unknown, check some additional vars if present
        if [[ -n "${VIP_ADDRESS:-}" ]] || [[ -n "${HOST_IP:-}" ]]; then
            REQUIRED_VARS+=("HOST_IP")
        fi
        ;;
esac

echo "Checking required variables..."
for var in "${REQUIRED_VARS[@]}"; do
    if [[ -z "${!var:-}" ]]; then
        err "Required variable $var is not set"
        ((VALIDATION_ERRORS++))
    else
        log "$var is set"
    fi
done

# Check optional but recommended variables
OPTIONAL_RECOMMENDED=(
    "GRAFANA_ADMIN_USER"
    "GRAFANA_ADMIN_PASSWORD"
)

echo ""
echo "Checking recommended variables..."
for var in "${OPTIONAL_RECOMMENDED[@]}"; do
    # Skip if already in required list
    if printf '%s\n' "${REQUIRED_VARS[@]}" | grep -qx "$var"; then
        continue
    fi
    if [[ -z "${!var:-}" ]]; then
        warn "Recommended variable $var is not set"
        ((VALIDATION_WARNINGS++))
    fi
done

echo ""
echo "Checking for default/weak passwords..."

# Check PIHOLE_PASSWORD
PIHOLE_PASSWORD="${PIHOLE_PASSWORD:-}"
if [[ -n "$PIHOLE_PASSWORD" ]]; then
    if [[ "$PIHOLE_PASSWORD" == "CHANGE_ME_REQUIRED" ]] || \
       [[ "$PIHOLE_PASSWORD" == "ChangeThisSecurePassword123!" ]] || \
       [[ "$PIHOLE_PASSWORD" == "admin" ]] || \
       [[ "$PIHOLE_PASSWORD" == "password" ]]; then
        err "PIHOLE_PASSWORD is using a default or weak value"
        err "Generate a secure password with: openssl rand -base64 32"
        ((VALIDATION_ERRORS++))
    elif [[ ${#PIHOLE_PASSWORD} -lt 8 ]]; then
        err "PIHOLE_PASSWORD is too short (minimum 8 characters)"
        ((VALIDATION_ERRORS++))
    else
        log "PIHOLE_PASSWORD appears secure"
    fi
fi

# Check GRAFANA_ADMIN_PASSWORD
GRAFANA_ADMIN_PASSWORD="${GRAFANA_ADMIN_PASSWORD:-}"
if [[ -n "$GRAFANA_ADMIN_PASSWORD" ]]; then
    if [[ "$GRAFANA_ADMIN_PASSWORD" == "CHANGE_ME_REQUIRED" ]] || \
       [[ "$GRAFANA_ADMIN_PASSWORD" == "ChangeThisGrafanaPassword!" ]] || \
       [[ "$GRAFANA_ADMIN_PASSWORD" == "admin" ]] || \
       [[ "$GRAFANA_ADMIN_PASSWORD" == "password" ]]; then
        err "GRAFANA_ADMIN_PASSWORD is using a default or weak value"
        err "Generate a secure password with: openssl rand -base64 32"
        ((VALIDATION_ERRORS++))
    elif [[ ${#GRAFANA_ADMIN_PASSWORD} -lt 8 ]]; then
        err "GRAFANA_ADMIN_PASSWORD is too short (minimum 8 characters)"
        ((VALIDATION_ERRORS++))
    else
        log "GRAFANA_ADMIN_PASSWORD appears secure"
    fi
fi

# Check VRRP_PASSWORD (only required for HA modes)
VRRP_PASSWORD="${VRRP_PASSWORD:-}"
if [[ -n "$VRRP_PASSWORD" ]]; then
    if [[ "$VRRP_PASSWORD" == "CHANGE_ME_REQUIRED" ]] || \
       [[ "$VRRP_PASSWORD" == "SecureVRRPPassword123!" ]] || \
       [[ "$VRRP_PASSWORD" == "admin" ]] || \
       [[ "$VRRP_PASSWORD" == "password" ]]; then
        err "VRRP_PASSWORD is using a default or weak value"
        err "Generate a secure password with: openssl rand -base64 20"
        ((VALIDATION_ERRORS++))
    elif [[ ${#VRRP_PASSWORD} -lt 8 ]]; then
        err "VRRP_PASSWORD is too short (minimum 8 characters)"
        ((VALIDATION_ERRORS++))
    else
        log "VRRP_PASSWORD appears secure"
    fi
fi

echo ""
echo "Checking IP address formats..."

# Validate IP addresses
validate_ip() {
    local ip=$1
    local name=$2
    
    # Allow empty values for optional IPs
    if [[ -z "$ip" ]]; then
        return 0
    fi
    
    if [[ ! $ip =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]]; then
        err "$name has invalid IP format: $ip"
        ((VALIDATION_ERRORS++))
        return 1
    fi
    
    IFS='.' read -ra ADDR <<< "$ip"
    for octet in "${ADDR[@]}"; do
        if [[ $octet -gt 255 ]]; then
            err "$name has invalid IP (octet > 255): $ip"
            ((VALIDATION_ERRORS++))
            return 1
        fi
    done
    
    log "$name IP is valid: $ip"
    return 0
}

# Extract network address and broadcast from CIDR
get_network_address() {
    local cidr=$1
    local ip="${cidr%/*}"
    local prefix="${cidr#*/}"
    
    # For /24 networks, network is .0 and broadcast is .255
    if [[ "$prefix" == "24" ]]; then
        IFS='.' read -ra ADDR <<< "$ip"
        echo "${ADDR[0]}.${ADDR[1]}.${ADDR[2]}.0"
    else
        # For other prefixes, just return the base (simplified)
        echo "$ip"
    fi
}

get_broadcast_address() {
    local cidr=$1
    local ip="${cidr%/*}"
    local prefix="${cidr#*/}"
    
    # For /24 networks, broadcast is .255
    if [[ "$prefix" == "24" ]]; then
        IFS='.' read -ra ADDR <<< "$ip"
        echo "${ADDR[0]}.${ADDR[1]}.${ADDR[2]}.255"
    else
        # For other prefixes, assume .255 (simplified)
        IFS='.' read -ra ADDR <<< "$ip"
        echo "${ADDR[0]}.${ADDR[1]}.${ADDR[2]}.255"
    fi
}

# Check if IP is in subnet (simplified for /24)
ip_in_subnet() {
    local ip=$1
    local subnet=$2
    local subnet_base="${subnet%/*}"
    
    IFS='.' read -ra IP_PARTS <<< "$ip"
    IFS='.' read -ra SUBNET_PARTS <<< "$subnet_base"
    
    # For /24, first 3 octets must match
    if [[ "${IP_PARTS[0]}" == "${SUBNET_PARTS[0]}" ]] && \
       [[ "${IP_PARTS[1]}" == "${SUBNET_PARTS[1]}" ]] && \
       [[ "${IP_PARTS[2]}" == "${SUBNET_PARTS[2]}" ]]; then
        return 0
    fi
    return 1
}

HOST_IP="${HOST_IP:-}"
PI1_IP="${PI1_IP:-}"
PI2_IP="${PI2_IP:-}"
VIP_ADDRESS="${VIP_ADDRESS:-}"
GATEWAY="${GATEWAY:-}"
SUBNET="${SUBNET:-}"
PRIMARY_DNS_IP="${PRIMARY_DNS_IP:-}"
SECONDARY_DNS_IP="${SECONDARY_DNS_IP:-}"

validate_ip "$HOST_IP" "HOST_IP"
validate_ip "$PI1_IP" "PI1_IP"
validate_ip "$PI2_IP" "PI2_IP"
validate_ip "$VIP_ADDRESS" "VIP_ADDRESS"
validate_ip "$GATEWAY" "GATEWAY"

# Also validate PRIMARY_DNS_IP and SECONDARY_DNS_IP if set
if [[ -n "$PRIMARY_DNS_IP" ]]; then
    validate_ip "$PRIMARY_DNS_IP" "PRIMARY_DNS_IP"
fi
if [[ -n "$SECONDARY_DNS_IP" ]]; then
    validate_ip "$SECONDARY_DNS_IP" "SECONDARY_DNS_IP"
fi

# Validate CIDR subnet
echo ""
echo "Checking network subnet..."
if [[ -n "$SUBNET" ]]; then
    if [[ ! "$SUBNET" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}/[0-9]{1,2}$ ]]; then
        err "SUBNET has invalid CIDR format: $SUBNET"
        ((VALIDATION_ERRORS++))
    else
        log "SUBNET is valid: $SUBNET"
        
        # Check VIP is not network or broadcast address
        if [[ -n "$VIP_ADDRESS" ]]; then
            NETWORK_ADDR=$(get_network_address "$SUBNET")
            BROADCAST_ADDR=$(get_broadcast_address "$SUBNET")
            
            if [[ "$VIP_ADDRESS" == "$NETWORK_ADDR" ]]; then
                err "VIP_ADDRESS ($VIP_ADDRESS) is the network address - please choose a different IP"
                ((VALIDATION_ERRORS++))
            elif [[ "$VIP_ADDRESS" == "$BROADCAST_ADDR" ]]; then
                err "VIP_ADDRESS ($VIP_ADDRESS) is the broadcast address - please choose a different IP (e.g., .249)"
                ((VALIDATION_ERRORS++))
            else
                log "VIP_ADDRESS is not network/broadcast address"
            fi
            
            # Check VIP is in the same subnet
            if ! ip_in_subnet "$VIP_ADDRESS" "$SUBNET"; then
                err "VIP_ADDRESS ($VIP_ADDRESS) is not in the subnet $SUBNET"
                ((VALIDATION_ERRORS++))
            else
                log "VIP_ADDRESS is in subnet $SUBNET"
            fi
        fi
        
        # Check HOST_IP is in subnet
        if [[ -n "$HOST_IP" ]]; then
            if ! ip_in_subnet "$HOST_IP" "$SUBNET"; then
                err "HOST_IP ($HOST_IP) is not in the subnet $SUBNET"
                ((VALIDATION_ERRORS++))
            else
                log "HOST_IP is in subnet $SUBNET"
            fi
        fi
        
        # Check PI1_IP and PI2_IP are in subnet (for two-pi-ha)
        if [[ -n "$PI1_IP" ]]; then
            if ! ip_in_subnet "$PI1_IP" "$SUBNET"; then
                err "PI1_IP ($PI1_IP) is not in the subnet $SUBNET"
                ((VALIDATION_ERRORS++))
            fi
        fi
        if [[ -n "$PI2_IP" ]]; then
            if ! ip_in_subnet "$PI2_IP" "$SUBNET"; then
                err "PI2_IP ($PI2_IP) is not in the subnet $SUBNET"
                ((VALIDATION_ERRORS++))
            fi
        fi
    fi
fi

# For two-pi-ha, check that HOST_IP matches either PI1_IP or PI2_IP
if [[ "${DEPLOYMENT_MODE:-}" == "two-pi-ha" ]]; then
    echo ""
    echo "Checking two-pi-ha specific configuration..."
    
    if [[ -n "$HOST_IP" ]] && [[ -n "$PI1_IP" ]] && [[ -n "$PI2_IP" ]]; then
        if [[ "$HOST_IP" != "$PI1_IP" ]] && [[ "$HOST_IP" != "$PI2_IP" ]]; then
            err "HOST_IP ($HOST_IP) should match either PI1_IP ($PI1_IP) or PI2_IP ($PI2_IP)"
            ((VALIDATION_ERRORS++))
        else
            log "HOST_IP matches one of the Pi IPs"
        fi
    fi
    
    # Check KEEPALIVED_PRIORITY is set
    KEEPALIVED_PRIORITY="${KEEPALIVED_PRIORITY:-}"
    if [[ -z "$KEEPALIVED_PRIORITY" ]]; then
        warn "KEEPALIVED_PRIORITY not set - using default. Set to 100 for Pi1 (MASTER) or 90 for Pi2 (BACKUP)"
        ((VALIDATION_WARNINGS++))
    else
        if [[ "$KEEPALIVED_PRIORITY" -lt 1 ]] || [[ "$KEEPALIVED_PRIORITY" -gt 255 ]]; then
            err "KEEPALIVED_PRIORITY must be between 1 and 255"
            ((VALIDATION_ERRORS++))
        else
            log "KEEPALIVED_PRIORITY is valid: $KEEPALIVED_PRIORITY"
        fi
    fi
fi

# Check file format (no syntax errors)
echo ""
echo "Checking .env file format..."
line_num=0
format_errors=0
while IFS= read -r line; do
    ((line_num++))
    
    # Skip empty lines and comments
    [[ -z "$line" || "$line" =~ ^[[:space:]]*# ]] && continue
    
    # Check if line matches KEY=VALUE format
    if ! [[ "$line" =~ ^[A-Za-z_][A-Za-z0-9_]*=.*$ ]]; then
        err "Line $line_num: Invalid format: $line"
        ((VALIDATION_ERRORS++))
        ((format_errors++))
    fi
done < "$ENV_FILE"

if [[ $format_errors -eq 0 ]]; then
    log ".env file format is valid"
fi

echo ""
echo "=========================================="
if [[ $VALIDATION_ERRORS -eq 0 ]]; then
    if [[ $VALIDATION_WARNINGS -gt 0 ]]; then
        warn "Validation PASSED with $VALIDATION_WARNINGS warnings"
    else
        log "Validation PASSED - .env file is ready for deployment"
    fi
    exit 0
else
    err "Validation FAILED with $VALIDATION_ERRORS errors"
    err "Please fix the errors above before deploying"
    exit 1
fi
