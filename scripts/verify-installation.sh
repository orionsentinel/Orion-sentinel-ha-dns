#!/usr/bin/env bash
# Comprehensive Installation Verification Script
# Tests the complete installation to ensure all components work correctly
# Usage: bash scripts/verify-installation.sh [--verbose]

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

# Test tracking
TESTS_PASSED=0
TESTS_FAILED=0
TESTS_WARNINGS=0
VERBOSE=false

# Parse arguments
for arg in "$@"; do
    case $arg in
        --verbose|-v)
            VERBOSE=true
            shift
            ;;
    esac
done

log_pass() {
    echo -e "${GREEN}[✓ PASS]${NC} $*"
    ((TESTS_PASSED++))
}

log_fail() {
    echo -e "${RED}[✗ FAIL]${NC} $*"
    ((TESTS_FAILED++))
}

log_warn() {
    echo -e "${YELLOW}[! WARN]${NC} $*"
    ((TESTS_WARNINGS++))
}

log_info() {
    echo -e "${BLUE}[ℹ INFO]${NC} $*"
}

log_section() {
    echo ""
    echo -e "${CYAN}${BOLD}╔════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}${BOLD}║  $*${NC}"
    echo -e "${CYAN}${BOLD}╚════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

show_banner() {
    clear
    echo -e "${CYAN}${BOLD}"
    cat << 'EOF'
╔═══════════════════════════════════════════════════════════════╗
║                                                               ║
║   Orion Sentinel DNS HA - Installation Verification          ║
║                                                               ║
╚═══════════════════════════════════════════════════════════════╝
EOF
    echo -e "${NC}"
}

# Test 1: System Requirements
test_system_requirements() {
    log_section "1. System Requirements"
    
    # Check OS
    if [[ "$(uname -s)" == "Linux" ]]; then
        log_pass "Operating System: Linux"
    else
        log_fail "Not running on Linux (OS: $(uname -s))"
    fi
    
    # Check architecture
    local arch=$(uname -m)
    if [[ "$arch" == "aarch64" || "$arch" == "armv7l" || "$arch" == "x86_64" ]]; then
        log_pass "Architecture: $arch (supported)"
    else
        log_warn "Architecture: $arch (may not be officially supported)"
    fi
    
    # Check memory
    if command -v free &> /dev/null; then
        local total_mem_mb=$(free -m | awk '/^Mem:/{print $2}')
        if [[ $total_mem_mb -ge 3500 ]]; then
            log_pass "Memory: ${total_mem_mb}MB (sufficient)"
        elif [[ $total_mem_mb -ge 1800 ]]; then
            log_warn "Memory: ${total_mem_mb}MB (minimum met, 4GB+ recommended)"
        else
            log_fail "Memory: ${total_mem_mb}MB (insufficient, need 2GB minimum)"
        fi
    else
        log_warn "Cannot determine memory size"
    fi
    
    # Check disk space
    if command -v df &> /dev/null; then
        local available_gb=$(df -BG "$REPO_ROOT" | awk 'NR==2 {print $4}' | sed 's/G//')
        if [[ $available_gb -ge 10 ]]; then
            log_pass "Disk Space: ${available_gb}GB available (sufficient)"
        elif [[ $available_gb -ge 5 ]]; then
            log_warn "Disk Space: ${available_gb}GB available (tight, 10GB+ recommended)"
        else
            log_fail "Disk Space: ${available_gb}GB available (insufficient)"
        fi
    fi
}

# Test 2: Required Software
test_required_software() {
    log_section "2. Required Software"
    
    # Check Docker
    if command -v docker &> /dev/null; then
        local docker_version=$(docker --version | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1)
        log_pass "Docker: Installed (version $docker_version)"
        
        # Check if Docker daemon is running
        if docker info &> /dev/null; then
            log_pass "Docker: Daemon is running"
        else
            log_fail "Docker: Daemon is not running (run: sudo systemctl start docker)"
        fi
        
        # Check Docker permissions
        if docker ps &> /dev/null; then
            log_pass "Docker: User has permissions"
        else
            log_warn "Docker: Permission denied (run: sudo usermod -aG docker \$USER)"
        fi
    else
        log_fail "Docker: Not installed (required)"
    fi
    
    # Check Docker Compose
    if docker compose version &> /dev/null; then
        local compose_version=$(docker compose version | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1)
        log_pass "Docker Compose: Plugin installed (version $compose_version)"
    elif command -v docker-compose &> /dev/null; then
        local compose_version=$(docker-compose --version | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1)
        log_warn "Docker Compose: Standalone version found (plugin recommended)"
    else
        log_fail "Docker Compose: Not installed (required)"
    fi
    
    # Check Git
    if command -v git &> /dev/null; then
        log_pass "Git: Installed"
    else
        log_warn "Git: Not installed (helpful for updates)"
    fi
    
    # Check curl/wget
    if command -v curl &> /dev/null; then
        log_pass "curl: Installed"
    elif command -v wget &> /dev/null; then
        log_pass "wget: Installed"
    else
        log_warn "curl/wget: Not installed (helpful for downloads)"
    fi
}

# Test 3: Repository Structure
test_repository_structure() {
    log_section "3. Repository Structure"
    
    local required_files=(
        "install.sh"
        "scripts/install.sh"
        ".env.example"
        "stacks/dns/docker-compose.yml"
        "stacks/observability/docker-compose.yml"
        "README.md"
        "INSTALL.md"
    )
    
    for file in "${required_files[@]}"; do
        if [[ -f "$REPO_ROOT/$file" ]]; then
            log_pass "File exists: $file"
        else
            log_fail "Missing file: $file"
        fi
    done
    
    local required_dirs=(
        "scripts"
        "stacks/dns"
        "stacks/observability"
        "profiles"
    )
    
    for dir in "${required_dirs[@]}"; do
        if [[ -d "$REPO_ROOT/$dir" ]]; then
            log_pass "Directory exists: $dir"
        else
            log_fail "Missing directory: $dir"
        fi
    done
}

# Test 4: Script Validation
test_script_validation() {
    log_section "4. Script Validation"
    
    local scripts=(
        "install.sh"
        "scripts/install.sh"
        "scripts/install-check.sh"
        "scripts/setup.sh"
        "scripts/deploy.sh"
        "scripts/verify-installation.sh"
    )
    
    for script in "${scripts[@]}"; do
        if [[ -f "$REPO_ROOT/$script" ]]; then
            # Check syntax
            if bash -n "$REPO_ROOT/$script" 2>/dev/null; then
                log_pass "Syntax valid: $script"
            else
                log_fail "Syntax error: $script"
            fi
            
            # Check executable
            if [[ -x "$REPO_ROOT/$script" ]]; then
                $VERBOSE && log_info "Executable: $script"
            else
                log_warn "Not executable: $script (chmod +x may be needed)"
            fi
        fi
    done
}

# Test 5: Docker Compose Files
test_docker_compose_files() {
    log_section "5. Docker Compose Files"
    
    local compose_files=(
        "stacks/dns/docker-compose.yml"
        "stacks/observability/docker-compose.yml"
        "stacks/ai-watchdog/docker-compose.yml"
        "stacks/setup-ui/docker-compose.yml"
    )
    
    for compose_file in "${compose_files[@]}"; do
        if [[ -f "$REPO_ROOT/$compose_file" ]]; then
            # Check basic structure (services with either image or build)
            if grep -q "services:" "$REPO_ROOT/$compose_file" && \
               (grep -q "image:" "$REPO_ROOT/$compose_file" || grep -q "build:" "$REPO_ROOT/$compose_file"); then
                log_pass "Valid structure: $compose_file"
            else
                log_fail "Invalid structure: $compose_file"
            fi
            
            # Try to validate with docker compose config (if .env exists)
            if [[ -f "$REPO_ROOT/.env" ]] && docker compose version &>/dev/null; then
                if docker compose -f "$REPO_ROOT/$compose_file" config >/dev/null 2>&1; then
                    $VERBOSE && log_info "Docker validates: $compose_file"
                else
                    log_warn "Docker validation failed: $compose_file (may need .env setup)"
                fi
            fi
        else
            log_fail "Missing: $compose_file"
        fi
    done
}

# Test 6: Configuration Files
test_configuration_files() {
    log_section "6. Configuration Files"
    
    # Check .env.example
    if [[ -f "$REPO_ROOT/.env.example" ]]; then
        log_pass ".env.example: Exists"
        
        local required_vars=(
            "HOST_IP"
            "PRIMARY_DNS_IP"
            "SECONDARY_DNS_IP"
            "VIP_ADDRESS"
            "PIHOLE_PASSWORD"
            "TZ"
            "SUBNET"
            "GATEWAY"
        )
        
        for var in "${required_vars[@]}"; do
            if grep -q "^${var}=" "$REPO_ROOT/.env.example"; then
                $VERBOSE && log_info "Variable defined: $var"
            else
                log_warn "Missing variable in .env.example: $var"
            fi
        done
    else
        log_fail ".env.example: Not found"
    fi
    
    # Check if .env exists
    if [[ -f "$REPO_ROOT/.env" ]]; then
        log_pass ".env: Exists (configured)"
        
        # Check for default passwords (security check)
        if grep -q "PIHOLE_PASSWORD=CHANGE_ME" "$REPO_ROOT/.env" 2>/dev/null; then
            log_warn "Default password detected in .env - CHANGE REQUIRED!"
        elif grep -q "PIHOLE_PASSWORD=" "$REPO_ROOT/.env"; then
            $VERBOSE && log_info "PIHOLE_PASSWORD is set"
        fi
    else
        log_warn ".env: Not found (needs configuration)"
    fi
    
    # Check Unbound configs
    if [[ -f "$REPO_ROOT/stacks/dns/unbound1/unbound.conf" ]]; then
        log_pass "Unbound config: Primary exists"
    else
        log_warn "Unbound config: Primary not found"
    fi
    
    if [[ -f "$REPO_ROOT/stacks/dns/unbound2/unbound.conf" ]]; then
        log_pass "Unbound config: Secondary exists"
    else
        log_warn "Unbound config: Secondary not found"
    fi
}

# Test 7: Network Configuration
test_network_configuration() {
    log_section "7. Network Configuration"
    
    # Check if Docker networks exist (only if Docker is running)
    if docker info &> /dev/null; then
        if docker network inspect dns_net &> /dev/null; then
            log_pass "Docker network: dns_net exists"
        else
            log_warn "Docker network: dns_net not found (will be created on deployment)"
        fi
        
        if docker network inspect observability_net &> /dev/null; then
            log_pass "Docker network: observability_net exists"
        else
            log_warn "Docker network: observability_net not found (will be created on deployment)"
        fi
    fi
    
    # Check network interface (if configured)
    if [[ -f "$REPO_ROOT/.env" ]]; then
        local interface=$(grep "^NETWORK_INTERFACE=" "$REPO_ROOT/.env" | cut -d'=' -f2)
        if [[ -n "$interface" ]] && ip link show "$interface" &> /dev/null; then
            log_pass "Network interface: $interface exists"
        elif [[ -n "$interface" ]]; then
            log_warn "Network interface: $interface not found"
        fi
    fi
}

# Test 8: Container Status
test_container_status() {
    log_section "8. Container Status (if deployed)"
    
    if ! docker info &> /dev/null; then
        log_warn "Docker not accessible, skipping container checks"
        return
    fi
    
    local containers=(
        "pihole_primary"
        "pihole_secondary"
        "unbound_primary"
        "unbound_secondary"
        "keepalived"
    )
    
    local deployed=false
    for container in "${containers[@]}"; do
        if docker ps -a --format '{{.Names}}' | grep -q "^${container}$"; then
            deployed=true
            if docker ps --format '{{.Names}}' | grep -q "^${container}$"; then
                log_pass "Container running: $container"
            else
                log_warn "Container exists but not running: $container"
            fi
        fi
    done
    
    if ! $deployed; then
        log_info "No containers deployed yet (run installation to deploy)"
    fi
}

# Test 9: Port Availability
test_port_availability() {
    log_section "9. Port Availability"
    
    # Only check if netstat or ss is available
    if ! command -v ss &> /dev/null && ! command -v netstat &> /dev/null; then
        log_warn "Cannot check ports (ss/netstat not available)"
        return
    fi
    
    local ports=(
        "53:DNS"
        "80:HTTP"
        "443:HTTPS"
        "5555:Setup UI"
        "8080:Web Wizard"
        "3000:Grafana"
        "9090:Prometheus"
    )
    
    for port_info in "${ports[@]}"; do
        local port="${port_info%%:*}"
        local service="${port_info##*:}"
        
        if command -v ss &> /dev/null; then
            if ss -tuln | grep -q ":${port} "; then
                log_info "Port $port ($service): In use"
            else
                $VERBOSE && log_info "Port $port ($service): Available"
            fi
        fi
    done
}

# Test 10: Documentation
test_documentation() {
    log_section "10. Documentation"
    
    local docs=(
        "README.md"
        "INSTALL.md"
        "QUICKSTART.md"
        "TROUBLESHOOTING.md"
        "USER_GUIDE.md"
    )
    
    for doc in "${docs[@]}"; do
        if [[ -f "$REPO_ROOT/$doc" ]]; then
            log_pass "Documentation: $doc"
        else
            log_warn "Documentation missing: $doc"
        fi
    done
}

# Show summary
show_summary() {
    log_section "Summary"
    
    local total=$((TESTS_PASSED + TESTS_FAILED + TESTS_WARNINGS))
    
    echo -e "${BOLD}Test Results:${NC}"
    echo -e "  ${GREEN}✓ Passed:  ${TESTS_PASSED}${NC}"
    echo -e "  ${RED}✗ Failed:  ${TESTS_FAILED}${NC}"
    echo -e "  ${YELLOW}! Warnings: ${TESTS_WARNINGS}${NC}"
    echo -e "  ${BLUE}Total:    ${total}${NC}"
    echo ""
    
    if [[ $TESTS_FAILED -eq 0 ]]; then
        echo -e "${GREEN}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo -e "${GREEN}${BOLD}  ✓ VERIFICATION PASSED${NC}"
        echo -e "${GREEN}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo ""
        if [[ $TESTS_WARNINGS -eq 0 ]]; then
            echo -e "${GREEN}System is ready for deployment!${NC}"
        else
            echo -e "${YELLOW}System is ready, but check warnings above.${NC}"
        fi
        echo ""
        echo -e "${CYAN}Next steps:${NC}"
        echo -e "  1. Configure .env file (if not already done)"
        echo -e "  2. Run: ${BOLD}bash scripts/install.sh${NC}"
        echo -e "  3. Follow the installation wizard"
        echo ""
        return 0
    else
        echo -e "${RED}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo -e "${RED}${BOLD}  ✗ VERIFICATION FAILED${NC}"
        echo -e "${RED}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo ""
        echo -e "${RED}Please fix the failed checks above before proceeding.${NC}"
        echo ""
        echo -e "${CYAN}Common fixes:${NC}"
        echo -e "  • Install Docker: Download and review https://get.docker.com first, then run with sudo sh"
        echo -e "  • Install Docker Compose: ${BOLD}sudo apt install docker-compose-plugin${NC}"
        echo -e "  • Add user to docker group: ${BOLD}sudo usermod -aG docker \$USER${NC}"
        echo ""
        return 1
    fi
}

# Main execution
main() {
    show_banner
    
    log_info "Starting installation verification..."
    log_info "Repository: $REPO_ROOT"
    echo ""
    
    test_system_requirements
    test_required_software
    test_repository_structure
    test_script_validation
    test_docker_compose_files
    test_configuration_files
    test_network_configuration
    test_container_status
    test_port_availability
    test_documentation
    
    show_summary
}

main "$@"
