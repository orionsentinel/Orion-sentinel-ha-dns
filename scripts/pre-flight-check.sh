#!/usr/bin/env bash
# Pre-Flight Check Script for Orion Sentinel DNS HA
# Comprehensive validation of system requirements and configuration
#
# Features:
# - System requirements validation
# - Docker and Docker Compose verification
# - Network configuration checks
# - Port availability validation
# - Disk space verification
# - SSH connectivity testing (for multi-node)
# - Configuration file validation
# - Security best practices checks
#
# Usage:
#   ./pre-flight-check.sh [options]
#
# Options:
#   --fix           Attempt to fix issues automatically
#   --verbose       Show detailed output
#   --json          Output results as JSON
#   --quick         Skip optional checks
#   -h, --help      Show this help message

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Configuration
MIN_RAM_MB=1024
MIN_DISK_GB=5
REQUIRED_PORTS=(53 80 443 5335 9100 9617 9167)
DOCKER_MIN_VERSION="20.10"

# State tracking
PASSED=0
WARNINGS=0
FAILED=0
RESULTS=()

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# Options
FIX_ISSUES=false
VERBOSE=false
JSON_OUTPUT=false
QUICK_MODE=false

# Show usage information
usage() {
    cat <<EOF
Usage: $0 [options]

Pre-Flight Check Script for Orion Sentinel DNS HA
Validates system requirements and configuration before deployment.

Options:
    --fix           Attempt to fix issues automatically
    --verbose       Show detailed output
    --json          Output results as JSON
    --quick         Skip optional checks
    -h, --help      Show this help message

Exit Codes:
    0   All checks passed
    1   One or more critical checks failed
    2   Warnings present but no critical failures

Examples:
    # Run all checks
    $0
    
    # Run checks and attempt fixes
    $0 --fix
    
    # Verbose output with JSON
    $0 --verbose --json

EOF
    exit 0
}

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --fix)
            FIX_ISSUES=true
            shift
            ;;
        --verbose)
            VERBOSE=true
            shift
            ;;
        --json)
            JSON_OUTPUT=true
            shift
            ;;
        --quick)
            QUICK_MODE=true
            shift
            ;;
        -h|--help)
            usage
            ;;
        *)
            echo "Unknown option: $1"
            usage
            ;;
    esac
done

# Logging functions
log_pass() {
    local msg="$1"
    PASSED=$((PASSED + 1))
    RESULTS+=("{\"check\": \"$msg\", \"status\": \"pass\"}")
    if [ "$JSON_OUTPUT" = "false" ]; then
        echo -e "${GREEN}✅ PASS${NC} $msg"
    fi
}

log_warn() {
    local msg="$1"
    local detail="${2:-}"
    WARNINGS=$((WARNINGS + 1))
    RESULTS+=("{\"check\": \"$msg\", \"status\": \"warn\", \"detail\": \"$detail\"}")
    if [ "$JSON_OUTPUT" = "false" ]; then
        echo -e "${YELLOW}⚠️  WARN${NC} $msg"
        [ -n "$detail" ] && [ "$VERBOSE" = "true" ] && echo -e "        ${YELLOW}$detail${NC}"
    fi
}

log_fail() {
    local msg="$1"
    local detail="${2:-}"
    FAILED=$((FAILED + 1))
    RESULTS+=("{\"check\": \"$msg\", \"status\": \"fail\", \"detail\": \"$detail\"}")
    if [ "$JSON_OUTPUT" = "false" ]; then
        echo -e "${RED}❌ FAIL${NC} $msg"
        [ -n "$detail" ] && echo -e "        ${RED}$detail${NC}"
    fi
}

log_info() {
    local msg="$1"
    if [ "$JSON_OUTPUT" = "false" ] && [ "$VERBOSE" = "true" ]; then
        echo -e "${BLUE}ℹ️  INFO${NC} $msg"
    fi
}

section() {
    if [ "$JSON_OUTPUT" = "false" ]; then
        echo ""
        echo -e "${CYAN}${BOLD}═══ $1 ═══${NC}"
        echo ""
    fi
}

# Check operating system
check_os() {
    section "Operating System"
    
    if [[ "$(uname -s)" == "Linux" ]]; then
        log_pass "Running on Linux"
        
        # Check for Raspberry Pi
        if [ -f /proc/device-tree/model ]; then
            local model
            model=$(tr -d '\0' < /proc/device-tree/model)
            log_pass "Raspberry Pi detected: $model"
        else
            log_info "Not running on Raspberry Pi hardware"
        fi
        
        # Check architecture
        local arch
        arch=$(uname -m)
        case "$arch" in
            aarch64|arm64)
                log_pass "64-bit ARM architecture (optimal for Pi 4/5)"
                ;;
            armv7l)
                log_warn "32-bit ARM architecture" "64-bit OS is recommended for better performance"
                ;;
            x86_64)
                log_pass "64-bit x86 architecture"
                ;;
            *)
                log_fail "Unsupported architecture: $arch"
                ;;
        esac
        
        # Check OS distribution
        if [ -f /etc/os-release ]; then
            # shellcheck disable=SC1091
            source /etc/os-release
            log_info "Distribution: $PRETTY_NAME"
        fi
    else
        log_fail "This script requires Linux"
    fi
}

# Check system resources
check_resources() {
    section "System Resources"
    
    # Check RAM
    local total_ram_kb
    total_ram_kb=$(grep MemTotal /proc/meminfo | awk '{print $2}')
    local total_ram_mb=$((total_ram_kb / 1024))
    
    if [ "$total_ram_mb" -ge 4096 ]; then
        log_pass "RAM: ${total_ram_mb}MB (≥4GB recommended)"
    elif [ "$total_ram_mb" -ge "$MIN_RAM_MB" ]; then
        log_warn "RAM: ${total_ram_mb}MB" "4GB+ recommended for full stack"
    else
        log_fail "RAM: ${total_ram_mb}MB" "Minimum ${MIN_RAM_MB}MB required"
    fi
    
    # Check available disk space
    local available_disk_kb
    available_disk_kb=$(df "$REPO_ROOT" | tail -1 | awk '{print $4}')
    local available_disk_gb=$((available_disk_kb / 1024 / 1024))
    
    if [ "$available_disk_gb" -ge 10 ]; then
        log_pass "Disk space: ${available_disk_gb}GB available"
    elif [ "$available_disk_gb" -ge "$MIN_DISK_GB" ]; then
        log_warn "Disk space: ${available_disk_gb}GB available" "10GB+ recommended"
    else
        log_fail "Disk space: ${available_disk_gb}GB available" "Minimum ${MIN_DISK_GB}GB required"
    fi
    
    # Check CPU cores
    local cpu_cores
    cpu_cores=$(nproc)
    if [ "$cpu_cores" -ge 4 ]; then
        log_pass "CPU cores: $cpu_cores"
    elif [ "$cpu_cores" -ge 2 ]; then
        log_warn "CPU cores: $cpu_cores" "4+ cores recommended for better performance"
    else
        log_warn "CPU cores: $cpu_cores" "Performance may be limited"
    fi
}

# Check Docker installation
check_docker() {
    section "Docker"
    
    if command -v docker &> /dev/null; then
        log_pass "Docker is installed"
        
        # Check Docker version
        local docker_version
        docker_version=$(docker version --format '{{.Server.Version}}' 2>/dev/null || echo "unknown")
        log_info "Docker version: $docker_version"
        
        # Check if Docker is running
        if docker info &> /dev/null; then
            log_pass "Docker daemon is running"
        else
            if [ "$FIX_ISSUES" = "true" ]; then
                log_info "Attempting to start Docker..."
                sudo systemctl start docker 2>/dev/null && \
                    log_pass "Docker daemon started" || \
                    log_fail "Docker daemon is not running" "Run: sudo systemctl start docker"
            else
                log_fail "Docker daemon is not running" "Run: sudo systemctl start docker"
            fi
        fi
        
        # Check if current user can use Docker
        if docker ps &> /dev/null; then
            log_pass "Current user can access Docker"
        else
            if [ "$FIX_ISSUES" = "true" ]; then
                log_info "Adding user to docker group..."
                sudo usermod -aG docker "$USER" 2>/dev/null && \
                    log_warn "User added to docker group" "Log out and back in to apply" || \
                    log_fail "Cannot access Docker" "Run: sudo usermod -aG docker $USER"
            else
                log_fail "Cannot access Docker without sudo" "Run: sudo usermod -aG docker $USER"
            fi
        fi
    else
        if [ "$FIX_ISSUES" = "true" ]; then
            log_info "Installing Docker..."
            curl -fsSL https://get.docker.com | sudo sh 2>/dev/null && \
                log_pass "Docker installed successfully" || \
                log_fail "Docker is not installed" "Run: curl -fsSL https://get.docker.com | sh"
        else
            log_fail "Docker is not installed" "Run: curl -fsSL https://get.docker.com | sh"
        fi
    fi
    
    # Check Docker Compose
    if docker compose version &> /dev/null; then
        local compose_version
        compose_version=$(docker compose version --short 2>/dev/null || echo "unknown")
        log_pass "Docker Compose is available (v$compose_version)"
    else
        if [ "$FIX_ISSUES" = "true" ]; then
            log_info "Installing Docker Compose plugin..."
            sudo apt-get update -qq && sudo apt-get install -y docker-compose-plugin 2>/dev/null && \
                log_pass "Docker Compose installed" || \
                log_fail "Docker Compose is not available"
        else
            log_fail "Docker Compose is not available" "Run: sudo apt-get install docker-compose-plugin"
        fi
    fi
}

# Check network configuration
check_network() {
    section "Network Configuration"
    
    # Check if we have a network interface
    local primary_interface
    primary_interface=$(ip route | grep default | head -1 | awk '{print $5}')
    if [ -n "$primary_interface" ]; then
        log_pass "Primary network interface: $primary_interface"
        
        # Get IP address
        local ip_address
        ip_address=$(ip -4 addr show "$primary_interface" | grep -oP '(?<=inet\s)\d+(\.\d+){3}')
        log_info "IP Address: $ip_address"
    else
        log_fail "No default network interface found"
    fi
    
    # Check if we have internet connectivity
    if ping -c 1 -W 3 8.8.8.8 &> /dev/null; then
        log_pass "Internet connectivity available"
    else
        log_warn "No internet connectivity" "Required for pulling Docker images"
    fi
    
    # Check DNS resolution
    if host google.com &> /dev/null 2>&1 || nslookup google.com &> /dev/null 2>&1; then
        log_pass "DNS resolution working"
    else
        log_warn "DNS resolution not working" "May need to configure upstream DNS"
    fi
}

# Check port availability
check_ports() {
    section "Port Availability"
    
    for port in "${REQUIRED_PORTS[@]}"; do
        if ss -tuln | grep -q ":${port} " 2>/dev/null; then
            local process
            process=$(ss -tulnp 2>/dev/null | grep ":${port} " | awk '{print $7}' | head -1)
            log_warn "Port $port is in use" "Used by: $process"
        else
            log_pass "Port $port is available"
        fi
    done
    
    # Check if port 53 is in use by systemd-resolved
    if systemctl is-active systemd-resolved &> /dev/null; then
        log_warn "systemd-resolved is running" "May conflict with Pi-hole on port 53"
        if [ "$FIX_ISSUES" = "true" ]; then
            log_info "To disable: sudo systemctl disable --now systemd-resolved"
        fi
    fi
}

# Check configuration files
check_configuration() {
    section "Configuration Files"
    
    # Check for .env file
    if [ -f "$REPO_ROOT/.env" ]; then
        log_pass ".env file exists"
        
        # Validate required variables
        local required_vars=("PIHOLE_PASSWORD" "TZ")
        local missing_vars=()
        
        for var in "${required_vars[@]}"; do
            if ! grep -q "^${var}=" "$REPO_ROOT/.env" 2>/dev/null; then
                missing_vars+=("$var")
            fi
        done
        
        if [ ${#missing_vars[@]} -eq 0 ]; then
            log_pass "Required environment variables are set"
        else
            log_warn "Missing environment variables" "${missing_vars[*]}"
        fi
        
        # Check for default/weak passwords
        if grep -q "PIHOLE_PASSWORD=.*changeme\|PIHOLE_PASSWORD=.*password\|PIHOLE_PASSWORD=.*admin" "$REPO_ROOT/.env" 2>/dev/null; then
            log_fail "Default/weak Pi-hole password detected" "Please set a strong password"
        else
            log_pass "Pi-hole password appears to be customized"
        fi
    else
        log_warn ".env file not found" "Copy from .env.example and configure"
    fi
    
    # Check for docker-compose files
    if [ -f "$REPO_ROOT/stacks/dns/docker-compose.yml" ]; then
        log_pass "DNS stack docker-compose.yml exists"
        
        # Validate docker-compose syntax
        if docker compose -f "$REPO_ROOT/stacks/dns/docker-compose.yml" config &> /dev/null; then
            log_pass "DNS docker-compose.yml is valid"
        else
            log_fail "DNS docker-compose.yml has syntax errors"
        fi
    else
        log_fail "DNS stack docker-compose.yml not found"
    fi
}

# Check multi-node configuration (if applicable)
check_multinode() {
    if [ "$QUICK_MODE" = "true" ]; then
        return
    fi
    
    section "Multi-Node Configuration"
    
    # Load .env to check if multi-node is configured
    if [ -f "$REPO_ROOT/.env" ]; then
        # shellcheck disable=SC1091
        source "$REPO_ROOT/.env" 2>/dev/null || true
    fi
    
    if [ -n "${PEER_IP:-}" ]; then
        log_info "Multi-node setup detected (PEER_IP=$PEER_IP)"
        
        # Check if peer is reachable
        if ping -c 1 -W 3 "$PEER_IP" &> /dev/null; then
            log_pass "Peer node is reachable"
            
            # Check SSH connectivity
            local ssh_key="${SYNC_SSH_KEY:-$HOME/.ssh/id_rsa}"
            local ssh_user="${SYNC_SSH_USER:-pi}"
            
            if [ -f "$ssh_key" ]; then
                if ssh -q -o BatchMode=yes -o ConnectTimeout=5 \
                    -i "$ssh_key" "${ssh_user}@${PEER_IP}" "exit 0" 2>/dev/null; then
                    log_pass "SSH connectivity to peer node"
                else
                    log_warn "SSH authentication failed" "Run: ssh-copy-id ${ssh_user}@${PEER_IP}"
                fi
            else
                log_warn "SSH key not found" "Generate with: ssh-keygen -t ed25519"
            fi
        else
            log_warn "Peer node is not reachable" "Check network connectivity to $PEER_IP"
        fi
    else
        log_info "Single-node setup (no PEER_IP configured)"
    fi
}

# Check security best practices
check_security() {
    if [ "$QUICK_MODE" = "true" ]; then
        return
    fi
    
    section "Security Checks"
    
    # Check if running as root
    if [ "$EUID" -eq 0 ]; then
        log_warn "Running as root" "It's recommended to run as a regular user with Docker access"
    else
        log_pass "Running as non-root user"
    fi
    
    # Check firewall
    if command -v ufw &> /dev/null; then
        if ufw status 2>/dev/null | grep -q "active"; then
            log_pass "Firewall (ufw) is active"
        else
            log_warn "Firewall (ufw) is not active" "Consider enabling: sudo ufw enable"
        fi
    elif command -v firewall-cmd &> /dev/null; then
        if firewall-cmd --state 2>/dev/null | grep -q "running"; then
            log_pass "Firewall (firewalld) is active"
        else
            log_warn "Firewall (firewalld) is not active"
        fi
    else
        log_warn "No firewall detected" "Consider installing and configuring a firewall"
    fi
    
    # Check if SSH key-based auth is configured
    if [ -f "$HOME/.ssh/authorized_keys" ]; then
        log_pass "SSH authorized_keys exists"
    else
        log_info "No SSH authorized_keys found"
    fi
    
    # Check if password authentication is disabled (recommended for Pi)
    if [ -f /etc/ssh/sshd_config ]; then
        if grep -q "^PasswordAuthentication no" /etc/ssh/sshd_config; then
            log_pass "SSH password authentication is disabled"
        else
            log_info "SSH password authentication may be enabled"
        fi
    fi
}

# Print summary
print_summary() {
    if [ "$JSON_OUTPUT" = "true" ]; then
        echo "{"
        echo "  \"summary\": {"
        echo "    \"passed\": $PASSED,"
        echo "    \"warnings\": $WARNINGS,"
        echo "    \"failed\": $FAILED"
        echo "  },"
        echo "  \"checks\": ["
        local first=true
        for result in "${RESULTS[@]}"; do
            if [ "$first" = "true" ]; then
                first=false
            else
                echo ","
            fi
            echo -n "    $result"
        done
        echo ""
        echo "  ]"
        echo "}"
    else
        echo ""
        echo "═══════════════════════════════════════════════════"
        echo -e "${BOLD}Pre-Flight Check Summary${NC}"
        echo "═══════════════════════════════════════════════════"
        echo ""
        echo -e "${GREEN}Passed:${NC}   $PASSED"
        echo -e "${YELLOW}Warnings:${NC} $WARNINGS"
        echo -e "${RED}Failed:${NC}   $FAILED"
        echo ""
        
        if [ $FAILED -gt 0 ]; then
            echo -e "${RED}${BOLD}❌ Pre-flight checks FAILED${NC}"
            echo "   Please address the failed checks before deployment."
            echo ""
            echo "   Run with --fix to attempt automatic fixes:"
            echo "   $0 --fix"
        elif [ $WARNINGS -gt 0 ]; then
            echo -e "${YELLOW}${BOLD}⚠️  Pre-flight checks passed with WARNINGS${NC}"
            echo "   Deployment should work, but consider addressing warnings."
        else
            echo -e "${GREEN}${BOLD}✅ All pre-flight checks PASSED${NC}"
            echo "   System is ready for deployment!"
        fi
        echo ""
    fi
}

# Main function
main() {
    if [ "$JSON_OUTPUT" = "false" ]; then
        echo ""
        echo -e "${CYAN}${BOLD}╔═══════════════════════════════════════════════════════════════╗${NC}"
        echo -e "${CYAN}${BOLD}║   Orion Sentinel DNS HA - Pre-Flight Check                    ║${NC}"
        echo -e "${CYAN}${BOLD}╚═══════════════════════════════════════════════════════════════╝${NC}"
    fi
    
    check_os
    check_resources
    check_docker
    check_network
    check_ports
    check_configuration
    check_multinode
    check_security
    
    print_summary
    
    # Exit with appropriate code
    if [ $FAILED -gt 0 ]; then
        exit 1
    elif [ $WARNINGS -gt 0 ]; then
        exit 2
    else
        exit 0
    fi
}

main
