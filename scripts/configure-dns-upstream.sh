#!/bin/bash
# ============================================================================
# configure-dns-upstream.sh
# ============================================================================
# Configures Pi-hole DNS upstream based on environment variables.
# This script outputs environment variable exports that should be sourced
# before running docker compose.
#
# Usage:
#   source <(./scripts/configure-dns-upstream.sh)
#   docker compose --profile <profile> up -d
#
# Or:
#   eval $(./scripts/configure-dns-upstream.sh)
#   docker compose --profile <profile> up -d
#
# Environment Variables (input):
#   NEXTDNS_ENABLED         - true/false (default: false)
#   NEXTDNS_DNS_IPV4        - NextDNS IPv4 endpoint (e.g., 45.90.28.xxx)
#   NEXTDNS_DNS_IPV6        - NextDNS IPv6 endpoint (optional)
#   UNBOUND_FALLBACK_SECONDARY - true/false (default: true)
#   UNBOUND_ONLY_MODE       - true/false (default: false, overrides NEXTDNS_ENABLED)
#   NODE_ROLE               - primary/secondary (for two-pi-ha mode)
#
# Environment Variables (output):
#   PIHOLE_DNS_PRIMARY      - Primary Pi-hole upstream DNS
#   PIHOLE_DNS_SECONDARY    - Secondary Pi-hole upstream DNS
#
# ============================================================================

set -e

# Default values
NEXTDNS_ENABLED="${NEXTDNS_ENABLED:-false}"
NEXTDNS_DNS_IPV4="${NEXTDNS_DNS_IPV4:-}"
NEXTDNS_DNS_IPV6="${NEXTDNS_DNS_IPV6:-}"
UNBOUND_FALLBACK_SECONDARY="${UNBOUND_FALLBACK_SECONDARY:-true}"
UNBOUND_ONLY_MODE="${UNBOUND_ONLY_MODE:-false}"
NODE_ROLE="${NODE_ROLE:-primary}"

# Unbound defaults
UNBOUND_PRIMARY="unbound_primary#5335"
UNBOUND_SECONDARY="unbound_secondary#5335"

# Function to print error and exit
error_exit() {
    echo "ERROR: $1" >&2
    exit 1
}

# Function to print info (to stderr so it doesn't interfere with export output)
info() {
    echo "INFO: $1" >&2
}

# Determine the DNS configuration mode
get_dns_mode() {
    if [[ "${UNBOUND_ONLY_MODE}" == "true" ]]; then
        echo "unbound-only"
    elif [[ "${NEXTDNS_ENABLED}" == "true" ]]; then
        echo "nextdns"
    else
        echo "unbound-only"
    fi
}

# Validate NextDNS configuration
validate_nextdns() {
    if [[ -z "${NEXTDNS_DNS_IPV4}" ]]; then
        error_exit "NEXTDNS_ENABLED=true but NEXTDNS_DNS_IPV4 is not set"
    fi
    
    # Basic IPv4 validation
    if ! [[ "${NEXTDNS_DNS_IPV4}" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        error_exit "NEXTDNS_DNS_IPV4 '${NEXTDNS_DNS_IPV4}' is not a valid IPv4 address"
    fi
    
    # Optional IPv6 validation
    if [[ -n "${NEXTDNS_DNS_IPV6}" ]] && ! [[ "${NEXTDNS_DNS_IPV6}" =~ : ]]; then
        error_exit "NEXTDNS_DNS_IPV6 '${NEXTDNS_DNS_IPV6}' is not a valid IPv6 address"
    fi
}

# Generate the DNS configuration
generate_config() {
    local mode=$(get_dns_mode)
    
    info "DNS Mode: ${mode}"
    info "Node Role: ${NODE_ROLE}"
    
    case "${mode}" in
        "unbound-only")
            # Original behavior: both Pi-holes use local Unbound
            info "Using Unbound-only mode (original behavior)"
            echo "export PIHOLE_DNS_PRIMARY=\"${UNBOUND_PRIMARY}\""
            echo "export PIHOLE_DNS_SECONDARY=\"${UNBOUND_SECONDARY}\""
            ;;
        
        "nextdns")
            validate_nextdns
            info "Using NextDNS mode"
            
            # Build NextDNS upstream string
            local nextdns_upstream="${NEXTDNS_DNS_IPV4}"
            if [[ -n "${NEXTDNS_DNS_IPV6}" ]]; then
                nextdns_upstream="${nextdns_upstream};${NEXTDNS_DNS_IPV6}"
            fi
            
            # Primary node: NextDNS only
            echo "export PIHOLE_DNS_PRIMARY=\"${nextdns_upstream}\""
            info "Primary Pi-hole upstream: ${nextdns_upstream}"
            
            # Secondary node: NextDNS + optional Unbound fallback
            if [[ "${UNBOUND_FALLBACK_SECONDARY}" == "true" ]]; then
                local secondary_upstream="${nextdns_upstream};${UNBOUND_SECONDARY}"
                echo "export PIHOLE_DNS_SECONDARY=\"${secondary_upstream}\""
                info "Secondary Pi-hole upstream: ${secondary_upstream} (with Unbound fallback)"
            else
                echo "export PIHOLE_DNS_SECONDARY=\"${nextdns_upstream}\""
                info "Secondary Pi-hole upstream: ${nextdns_upstream} (no Unbound fallback)"
            fi
            ;;
        
        *)
            error_exit "Unknown DNS mode: ${mode}"
            ;;
    esac
    
    # Export mode for use by other scripts
    echo "export DNS_UPSTREAM_MODE=\"${mode}\""
}

# Main execution
main() {
    if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
        cat << 'EOF'
Usage: source <(./scripts/configure-dns-upstream.sh)
       eval $(./scripts/configure-dns-upstream.sh)

Configures Pi-hole DNS upstream based on environment variables.

Environment Variables:
  NEXTDNS_ENABLED           Enable NextDNS as primary upstream (true/false)
  NEXTDNS_DNS_IPV4          NextDNS IPv4 endpoint
  NEXTDNS_DNS_IPV6          NextDNS IPv6 endpoint (optional)
  UNBOUND_FALLBACK_SECONDARY  Keep Unbound fallback on secondary (true/false)
  UNBOUND_ONLY_MODE         Force Unbound-only mode (true/false)
  NODE_ROLE                 Node role: primary or secondary

Examples:
  # Use default Unbound-only mode
  source <(./scripts/configure-dns-upstream.sh)

  # Enable NextDNS
  export NEXTDNS_ENABLED=true
  export NEXTDNS_DNS_IPV4=45.90.28.123
  source <(./scripts/configure-dns-upstream.sh)

  # NextDNS without Unbound fallback on secondary
  export NEXTDNS_ENABLED=true
  export NEXTDNS_DNS_IPV4=45.90.28.123
  export UNBOUND_FALLBACK_SECONDARY=false
  source <(./scripts/configure-dns-upstream.sh)
EOF
        exit 0
    fi
    
    generate_config
}

main "$@"
