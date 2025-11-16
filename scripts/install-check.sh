#!/usr/bin/env bash
# Pre-installation validation script for rpi-ha-dns-stack
# Checks all prerequisites before installation begins
# Provides detailed report of system readiness

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m' # No Color

log() { echo -e "${GREEN}[✓]${NC} $*"; }
warn() { echo -e "${YELLOW}[!]${NC} $*"; }
err() { echo -e "${RED}[✗]${NC} $*"; }
info() { echo -e "${BLUE}[i]${NC} $*"; }
section() { echo -e "\n${CYAN}${BOLD}═══ $* ═══${NC}\n"; }

# Track issues
ISSUES_FOUND=0
WARNINGS_FOUND=0

show_banner() {
    clear
    echo -e "${CYAN}${BOLD}"
    cat << 'EOF'
╔═══════════════════════════════════════════════════════════════╗
║                                                               ║
║    RPi HA DNS Stack - Pre-Installation Check                 ║
║                                                               ║
╚═══════════════════════════════════════════════════════════════╝
EOF
    echo -e "${NC}"
}

check_os_compatibility() {
    section "Operating System Compatibility"
    
    # Check if running on Linux
    if [[ "$(uname -s)" != "Linux" ]]; then
        err "Not running on Linux - This system requires Linux"
        ((ISSUES_FOUND++))
        return 1
    fi
    log "Running on Linux"
    
    # Check distribution
    if [[ -f /etc/os-release ]]; then
        # shellcheck disable=SC1091
        source /etc/os-release
        case "$ID" in
            raspbian|debian|ubuntu)
                log "Supported OS: $PRETTY_NAME"
                ;;
            *)
                warn "Untested OS: $PRETTY_NAME (Debian/Ubuntu-based distros recommended)"
                ((WARNINGS_FOUND++))
                ;;
        esac
    else
        warn "Cannot determine OS distribution"
        ((WARNINGS_FOUND++))
    fi
    
    # Check architecture
    ARCH=$(uname -m)
    case "$ARCH" in
        aarch64|armv7l|x86_64)
            log "Supported architecture: $ARCH"
            ;;
        *)
            err "Unsupported architecture: $ARCH (requires ARM or x86_64)"
            ((ISSUES_FOUND++))
            return 1
            ;;
    esac
    
    # Check if running on Raspberry Pi
    if [[ -f /proc/device-tree/model ]]; then
        MODEL=$(tr -d '\0' < /proc/device-tree/model)
        log "Detected Raspberry Pi: $MODEL"
    else
        info "Not running on Raspberry Pi hardware (generic Linux detected)"
    fi
    
    return 0
}

check_disk_space() {
    section "Disk Space"
    
    # Get available space in GB
    AVAILABLE_GB=$(df -BG / | awk 'NR==2 {print $4}' | sed 's/G//')
    REQUIRED_MIN=5
    REQUIRED_REC=10
    
    info "Available disk space: ${AVAILABLE_GB}GB"
    
    if [[ "$AVAILABLE_GB" -lt "$REQUIRED_MIN" ]]; then
        err "Insufficient disk space: ${AVAILABLE_GB}GB (minimum ${REQUIRED_MIN}GB required)"
        ((ISSUES_FOUND++))
    elif [[ "$AVAILABLE_GB" -lt "$REQUIRED_REC" ]]; then
        warn "Limited disk space: ${AVAILABLE_GB}GB (${REQUIRED_REC}GB recommended)"
        ((WARNINGS_FOUND++))
    else
        log "Sufficient disk space: ${AVAILABLE_GB}GB"
    fi
}

check_memory() {
    section "Memory (RAM)"
    
    # Get total memory in MB
    TOTAL_MEM_KB=$(grep MemTotal /proc/meminfo | awk '{print $2}')
    TOTAL_MEM_MB=$((TOTAL_MEM_KB / 1024))
    REQUIRED_MIN=1024
    REQUIRED_REC=2048
    
    info "Total memory: ${TOTAL_MEM_MB}MB"
    
    if [[ "$TOTAL_MEM_MB" -lt "$REQUIRED_MIN" ]]; then
        err "Insufficient memory: ${TOTAL_MEM_MB}MB (minimum ${REQUIRED_MIN}MB required)"
        ((ISSUES_FOUND++))
    elif [[ "$TOTAL_MEM_MB" -lt "$REQUIRED_REC" ]]; then
        warn "Limited memory: ${TOTAL_MEM_MB}MB (${REQUIRED_REC}MB recommended for optimal performance)"
        ((WARNINGS_FOUND++))
    else
        log "Sufficient memory: ${TOTAL_MEM_MB}MB"
    fi
}

check_network_connectivity() {
    section "Network Connectivity"
    
    # Check if we can resolve DNS
    if host -W 3 google.com >/dev/null 2>&1; then
        log "DNS resolution working"
    else
        warn "DNS resolution issues detected"
        ((WARNINGS_FOUND++))
    fi
    
    # Check internet connectivity
    if ping -c 1 -W 3 8.8.8.8 >/dev/null 2>&1; then
        log "Internet connectivity working"
    else
        err "No internet connectivity detected (required for installation)"
        ((ISSUES_FOUND++))
    fi
    
    # Check if Docker Hub is accessible
    if curl -s --connect-timeout 5 https://hub.docker.com >/dev/null 2>&1; then
        log "Docker Hub accessible"
    else
        warn "Cannot reach Docker Hub (may cause issues downloading container images)"
        ((WARNINGS_FOUND++))
    fi
}

check_docker() {
    section "Docker"
    
    if command -v docker &> /dev/null; then
        log "Docker is installed"
        DOCKER_VERSION=$(docker --version | awk '{print $3}' | sed 's/,//')
        info "Docker version: $DOCKER_VERSION"
        
        # Check if Docker is running
        if docker info >/dev/null 2>&1; then
            log "Docker daemon is running"
            
            # Check Docker permissions
            if docker ps >/dev/null 2>&1; then
                log "Current user has Docker permissions"
            else
                warn "Current user may not have Docker permissions (consider adding user to docker group)"
                ((WARNINGS_FOUND++))
            fi
        else
            err "Docker daemon is not running"
            ((ISSUES_FOUND++))
        fi
        
        # Check Docker Compose
        if docker compose version >/dev/null 2>&1; then
            log "Docker Compose plugin is installed"
            COMPOSE_VERSION=$(docker compose version | awk '{print $4}')
            info "Docker Compose version: $COMPOSE_VERSION"
        else
            warn "Docker Compose plugin not installed (will be installed during setup)"
            ((WARNINGS_FOUND++))
        fi
    else
        info "Docker not installed (will be installed during setup)"
    fi
}

check_required_tools() {
    section "Required Tools"
    
    local tools=("git" "curl")
    local missing_tools=()
    
    for tool in "${tools[@]}"; do
        if command -v "$tool" &> /dev/null; then
            log "$tool is installed"
        else
            err "$tool is not installed"
            missing_tools+=("$tool")
            ((ISSUES_FOUND++))
        fi
    done
    
    if [[ ${#missing_tools[@]} -gt 0 ]]; then
        info "Missing tools will be installed during setup: ${missing_tools[*]}"
    fi
}

check_ports() {
    section "Port Availability"
    
    # Check critical ports
    local ports=(
        "53:DNS"
        "80:Pi-hole Web Interface"
        "443:HTTPS (optional)"
        "3000:Grafana"
        "5555:Setup UI"
        "9090:Prometheus"
    )
    
    for port_info in "${ports[@]}"; do
        port="${port_info%%:*}"
        service="${port_info#*:}"
        
        if netstat -tuln 2>/dev/null | grep -q ":${port} " || ss -tuln 2>/dev/null | grep -q ":${port} "; then
            warn "Port $port ($service) is already in use"
            ((WARNINGS_FOUND++))
        else
            log "Port $port ($service) is available"
        fi
    done
}

check_permissions() {
    section "Permissions"
    
    # Check if running as root
    if [[ $EUID -eq 0 ]]; then
        warn "Running as root (not recommended, but will work)"
        ((WARNINGS_FOUND++))
    else
        log "Running as non-root user (recommended)"
        
        # Check sudo access
        if sudo -n true 2>/dev/null; then
            log "Has passwordless sudo access"
        elif sudo -v 2>/dev/null; then
            log "Has sudo access (may prompt for password)"
        else
            warn "No sudo access (may need to install dependencies manually)"
            ((WARNINGS_FOUND++))
        fi
    fi
}

show_summary() {
    section "Pre-Installation Check Summary"
    
    echo ""
    if [[ $ISSUES_FOUND -eq 0 ]]; then
        echo -e "${GREEN}${BOLD}✓ System Ready for Installation${NC}"
        echo ""
        echo -e "${GREEN}No critical issues found!${NC}"
        if [[ $WARNINGS_FOUND -gt 0 ]]; then
            echo -e "${YELLOW}$WARNINGS_FOUND warning(s) detected - installation may proceed with caution${NC}"
        fi
        echo ""
        echo -e "${CYAN}You can now proceed with installation:${NC}"
        echo -e "  ${BOLD}bash install.sh${NC}"
        echo ""
        return 0
    else
        echo -e "${RED}${BOLD}✗ System Not Ready${NC}"
        echo ""
        echo -e "${RED}$ISSUES_FOUND critical issue(s) found${NC}"
        if [[ $WARNINGS_FOUND -gt 0 ]]; then
            echo -e "${YELLOW}$WARNINGS_FOUND warning(s) detected${NC}"
        fi
        echo ""
        echo -e "${CYAN}Please resolve the issues above before proceeding with installation${NC}"
        echo ""
        return 1
    fi
}

# Main execution
main() {
    show_banner
    
    info "Checking system prerequisites for RPi HA DNS Stack installation..."
    echo ""
    
    check_os_compatibility
    check_disk_space
    check_memory
    check_network_connectivity
    check_required_tools
    check_docker
    check_ports
    check_permissions
    
    show_summary
}

main "$@"
