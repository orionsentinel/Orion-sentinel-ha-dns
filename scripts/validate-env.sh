#!/usr/bin/env bash
# Validate .env file for required variables and secure passwords
# This script checks for:
# - Required variables are present
# - Passwords are not default/weak values
# - Proper formatting of KEY=VALUE pairs

set -u
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

# Check if .env file exists
if [[ ! -f "$ENV_FILE" ]]; then
    err ".env file not found at $ENV_FILE"
    err "Please create one from .env.example: cp .env.example .env"
    exit 1
fi

log "Validating $ENV_FILE"
echo ""

# Load environment variables
set -a
source "$ENV_FILE" 2>/dev/null || {
    err "Failed to source .env file - it may have syntax errors"
    ((VALIDATION_ERRORS++))
}
set +a

# Required variables
REQUIRED_VARS=(
    "HOST_IP"
    "PRIMARY_DNS_IP"
    "SECONDARY_DNS_IP"
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

echo "Checking required variables..."
for var in "${REQUIRED_VARS[@]}"; do
    if [[ -z "${!var:-}" ]]; then
        err "Required variable $var is not set"
        ((VALIDATION_ERRORS++))
    else
        log "$var is set"
    fi
done

echo ""
echo "Checking for default/weak passwords..."

# Check PIHOLE_PASSWORD
if [[ "${PIHOLE_PASSWORD:-}" == "CHANGE_ME_REQUIRED" ]] || \
   [[ "${PIHOLE_PASSWORD:-}" == "ChangeThisSecurePassword123!" ]] || \
   [[ "${PIHOLE_PASSWORD:-}" == "admin" ]] || \
   [[ "${PIHOLE_PASSWORD:-}" == "password" ]]; then
    err "PIHOLE_PASSWORD is using a default or weak value"
    err "Generate a secure password with: openssl rand -base64 32"
    ((VALIDATION_ERRORS++))
elif [[ ${#PIHOLE_PASSWORD} -lt 8 ]]; then
    err "PIHOLE_PASSWORD is too short (minimum 8 characters)"
    ((VALIDATION_ERRORS++))
else
    log "PIHOLE_PASSWORD appears secure"
fi

# Check GRAFANA_ADMIN_PASSWORD
if [[ "${GRAFANA_ADMIN_PASSWORD:-}" == "CHANGE_ME_REQUIRED" ]] || \
   [[ "${GRAFANA_ADMIN_PASSWORD:-}" == "ChangeThisGrafanaPassword!" ]] || \
   [[ "${GRAFANA_ADMIN_PASSWORD:-}" == "admin" ]] || \
   [[ "${GRAFANA_ADMIN_PASSWORD:-}" == "password" ]]; then
    err "GRAFANA_ADMIN_PASSWORD is using a default or weak value"
    err "Generate a secure password with: openssl rand -base64 32"
    ((VALIDATION_ERRORS++))
elif [[ ${#GRAFANA_ADMIN_PASSWORD} -lt 8 ]]; then
    err "GRAFANA_ADMIN_PASSWORD is too short (minimum 8 characters)"
    ((VALIDATION_ERRORS++))
else
    log "GRAFANA_ADMIN_PASSWORD appears secure"
fi

# Check VRRP_PASSWORD
if [[ "${VRRP_PASSWORD:-}" == "CHANGE_ME_REQUIRED" ]] || \
   [[ "${VRRP_PASSWORD:-}" == "SecureVRRPPassword123!" ]] || \
   [[ "${VRRP_PASSWORD:-}" == "admin" ]] || \
   [[ "${VRRP_PASSWORD:-}" == "password" ]]; then
    err "VRRP_PASSWORD is using a default or weak value"
    err "Generate a secure password with: openssl rand -base64 20"
    ((VALIDATION_ERRORS++))
elif [[ ${#VRRP_PASSWORD} -lt 8 ]]; then
    err "VRRP_PASSWORD is too short (minimum 8 characters)"
    ((VALIDATION_ERRORS++))
else
    log "VRRP_PASSWORD appears secure"
fi

echo ""
echo "Checking IP address formats..."

# Validate IP addresses
validate_ip() {
    local ip=$1
    local name=$2
    
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

validate_ip "${HOST_IP:-}" "HOST_IP"
validate_ip "${PRIMARY_DNS_IP:-}" "PRIMARY_DNS_IP"
validate_ip "${SECONDARY_DNS_IP:-}" "SECONDARY_DNS_IP"
validate_ip "${VIP_ADDRESS:-}" "VIP_ADDRESS"
validate_ip "${GATEWAY:-}" "GATEWAY"

# Validate CIDR subnet
echo ""
echo "Checking network subnet..."
if [[ ! "${SUBNET:-}" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}/[0-9]{1,2}$ ]]; then
    err "SUBNET has invalid CIDR format: ${SUBNET:-}"
    ((VALIDATION_ERRORS++))
else
    log "SUBNET is valid: ${SUBNET:-}"
fi

# Check file format (no syntax errors)
echo ""
echo "Checking .env file format..."
line_num=0
while IFS= read -r line; do
    ((line_num++))
    
    # Skip empty lines and comments
    [[ -z "$line" || "$line" =~ ^[[:space:]]*# ]] && continue
    
    # Check if line matches KEY=VALUE format
    if ! [[ "$line" =~ ^[A-Za-z_][A-Za-z0-9_]*=.*$ ]]; then
        err "Line $line_num: Invalid format: $line"
        ((VALIDATION_ERRORS++))
    fi
done < "$ENV_FILE"

if [[ $VALIDATION_ERRORS -eq 0 ]]; then
    log ".env file format is valid"
fi

echo ""
echo "=========================================="
if [[ $VALIDATION_ERRORS -eq 0 ]]; then
    log "Validation PASSED - .env file is ready for deployment"
    exit 0
else
    err "Validation FAILED with $VALIDATION_ERRORS errors"
    err "Please fix the errors above before deploying"
    exit 1
fi
