#!/usr/bin/env bash
# =============================================================================
# Deployment Dry-Run Test Script for Orion Sentinel DNS HA
# =============================================================================
#
# This script performs a comprehensive dry-run test of the deployment
# configuration WITHOUT actually deploying any services. It validates:
#
# 1. Docker Compose configuration syntax and structure
# 2. Build contexts and Dockerfiles
# 3. Environment variable completeness
# 4. Network configuration
# 5. Volume mounts and file dependencies
#
# Usage:
#   ./scripts/test-deployment-dry-run.sh [options]
#
# Options:
#   --profile=PROFILE    Test specific profile (dns-core, exporters, all)
#   --verbose            Show detailed output
#   --help               Show this help
#
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || (cd "$SCRIPT_DIR/.." && pwd))"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

# Options
PROFILE="dns-core"
VERBOSE=false

# Results tracking
TESTS_PASSED=0
TESTS_FAILED=0
TESTS_WARNED=0

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --profile=*)
            PROFILE="${1#*=}"
            shift
            ;;
        --verbose)
            VERBOSE=true
            shift
            ;;
        --help)
            echo "Usage: $0 [--profile=PROFILE] [--verbose]"
            echo ""
            echo "Options:"
            echo "  --profile=PROFILE  Test specific profile (dns-core, exporters, all)"
            echo "  --verbose          Show detailed output"
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done

# Logging functions
log_pass() {
    echo -e "${GREEN}✅ PASS${NC} $*"
    ((TESTS_PASSED++)) || true
}

log_fail() {
    echo -e "${RED}❌ FAIL${NC} $*"
    ((TESTS_FAILED++)) || true
}

log_warn() {
    echo -e "${YELLOW}⚠️  WARN${NC} $*"
    ((TESTS_WARNED++)) || true
}

log_info() {
    if [ "$VERBOSE" = true ]; then
        echo -e "${BLUE}ℹ️  INFO${NC} $*"
    fi
}

section() {
    echo ""
    echo -e "${CYAN}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${CYAN}${BOLD}  $*${NC}"
    echo -e "${CYAN}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
}

# =============================================================================
# Test 1: Docker and Docker Compose Availability
# =============================================================================
test_docker_available() {
    section "1. Docker Environment"
    
    if command -v docker &>/dev/null; then
        local docker_version
        docker_version=$(docker version --format '{{.Server.Version}}' 2>/dev/null || echo "unknown")
        log_pass "Docker is installed (version: $docker_version)"
    else
        log_fail "Docker is not installed"
        return 1
    fi
    
    if docker info &>/dev/null; then
        log_pass "Docker daemon is running"
    else
        log_fail "Docker daemon is not accessible"
        return 1
    fi
    
    if docker compose version &>/dev/null; then
        local compose_version
        compose_version=$(docker compose version --short 2>/dev/null || echo "unknown")
        log_pass "Docker Compose is available (version: $compose_version)"
    else
        log_fail "Docker Compose is not available"
        return 1
    fi
    
    return 0
}

# =============================================================================
# Test 2: Environment Configuration
# =============================================================================
test_environment_config() {
    section "2. Environment Configuration"
    
    cd "$REPO_ROOT" || exit 1
    
    # Check for .env file
    if [[ -f .env ]]; then
        log_pass ".env file exists"
    elif [[ -f .env.example ]]; then
        log_warn ".env file not found - creating from .env.example for testing"
        cp .env.example .env
    else
        log_fail "No .env or .env.example file found"
        return 1
    fi
    
    # Check required variables
    local required_vars=("PIHOLE_PASSWORD" "VIP_ADDRESS" "VRRP_PASSWORD")
    for var in "${required_vars[@]}"; do
        if grep -q "^${var}=" .env 2>/dev/null; then
            log_pass "Required variable $var is defined"
        else
            log_fail "Required variable $var is missing"
        fi
    done
    
    return 0
}

# =============================================================================
# Test 3: Main Compose File Validation
# =============================================================================
test_main_compose() {
    section "3. Main Compose File (compose.yml)"
    
    cd "$REPO_ROOT" || exit 1
    
    if [[ ! -f compose.yml ]]; then
        log_fail "compose.yml not found"
        return 1
    fi
    log_pass "compose.yml exists"
    
    # Validate compose syntax
    if docker compose config --quiet 2>/dev/null; then
        log_pass "compose.yml syntax is valid"
    else
        log_fail "compose.yml has syntax errors"
        if [ "$VERBOSE" = true ]; then
            docker compose config 2>&1 | head -20
        fi
        return 1
    fi
    
    # Test with profile
    if docker compose --profile "$PROFILE" config --quiet 2>/dev/null; then
        log_pass "Profile '$PROFILE' configuration is valid"
        
        # Count services
        local service_count
        service_count=$(docker compose --profile "$PROFILE" config --services 2>/dev/null | wc -l)
        log_info "Found $service_count services in profile '$PROFILE'"
    else
        log_fail "Profile '$PROFILE' configuration has errors"
        return 1
    fi
    
    return 0
}

# =============================================================================
# Test 4: Build Contexts and Dockerfiles
# =============================================================================
test_build_contexts() {
    section "4. Build Contexts and Dockerfiles"
    
    cd "$REPO_ROOT" || exit 1
    
    # Check Unbound build context
    local unbound_dir="config/unbound"
    if [[ -d "$unbound_dir" ]]; then
        log_pass "Unbound config directory exists"
        
        if [[ -f "$unbound_dir/Dockerfile" ]]; then
            log_pass "Unbound Dockerfile exists"
        else
            log_fail "Unbound Dockerfile missing"
        fi
        
        if [[ -f "$unbound_dir/unbound.conf" ]]; then
            log_pass "Unbound configuration file exists"
        else
            log_fail "Unbound configuration file missing"
        fi
        
        if [[ -f "$unbound_dir/entrypoint.sh" ]]; then
            log_pass "Unbound entrypoint script exists"
        else
            log_fail "Unbound entrypoint script missing"
        fi
    else
        log_fail "Unbound config directory missing"
    fi
    
    # Check Keepalived build context
    local keepalived_dir="config/keepalived"
    if [[ -d "$keepalived_dir" ]]; then
        log_pass "Keepalived config directory exists"
        
        if [[ -f "$keepalived_dir/Dockerfile" ]]; then
            log_pass "Keepalived Dockerfile exists"
        else
            log_fail "Keepalived Dockerfile missing"
        fi
        
        if [[ -f "$keepalived_dir/keepalived.conf.tmpl" ]]; then
            log_pass "Keepalived template exists"
        else
            log_fail "Keepalived template missing"
        fi
        
        if [[ -f "$keepalived_dir/entrypoint.sh" ]]; then
            log_pass "Keepalived entrypoint script exists"
        else
            log_fail "Keepalived entrypoint script missing"
        fi
    else
        log_fail "Keepalived config directory missing"
    fi
    
    return 0
}

# =============================================================================
# Test 5: Required Scripts and Dependencies
# =============================================================================
test_scripts() {
    section "5. Required Scripts"
    
    cd "$REPO_ROOT" || exit 1
    
    local required_scripts=(
        "scripts/check-dns.sh"
        "scripts/notify-master.sh"
        "scripts/notify-backup.sh"
        "scripts/notify-fault.sh"
        "scripts/health-check.sh"
        "scripts/pre-flight-check.sh"
        "scripts/validate-env.sh"
    )
    
    for script in "${required_scripts[@]}"; do
        if [[ -f "$script" ]]; then
            if [[ -x "$script" ]]; then
                log_pass "$script exists and is executable"
            else
                log_warn "$script exists but is not executable"
            fi
        else
            log_fail "$script is missing"
        fi
    done
    
    # Syntax check critical scripts
    for script in scripts/check-dns.sh scripts/notify-master.sh; do
        if [[ -f "$script" ]]; then
            if bash -n "$script" 2>/dev/null; then
                log_pass "$script syntax is valid"
            else
                log_fail "$script has syntax errors"
            fi
        fi
    done
    
    return 0
}

# =============================================================================
# Test 6: Volume Mounts Validation
# =============================================================================
test_volume_mounts() {
    section "6. Volume Mount Dependencies"
    
    cd "$REPO_ROOT" || exit 1
    
    # Check that mounted files exist
    local mounted_files=(
        "config/keepalived/keepalived.conf.tmpl"
        "config/unbound/unbound.conf"
        "scripts/check-dns.sh"
        "scripts/notify-master.sh"
        "scripts/notify-backup.sh"
        "scripts/notify-fault.sh"
    )
    
    for file in "${mounted_files[@]}"; do
        if [[ -f "$file" ]]; then
            log_pass "Mounted file exists: $file"
        else
            log_fail "Mounted file missing: $file"
        fi
    done
    
    return 0
}

# =============================================================================
# Test 7: Network Configuration
# =============================================================================
test_network_config() {
    section "7. Network Configuration"
    
    cd "$REPO_ROOT" || exit 1
    
    # Check if compose defines networks
    if grep -q "networks:" compose.yml; then
        log_pass "Networks are defined in compose.yml"
    else
        log_warn "No explicit networks defined in compose.yml"
    fi
    
    # Check for dns_net
    if grep -q "dns_net:" compose.yml; then
        log_pass "DNS network (dns_net) is defined"
    else
        log_fail "DNS network (dns_net) not found in compose.yml"
    fi
    
    return 0
}

# =============================================================================
# Test 8: Legacy Stacks Validation
# =============================================================================
test_legacy_stacks() {
    section "8. Legacy Stacks (for compatibility)"
    
    cd "$REPO_ROOT" || exit 1
    
    local stack_dirs=(
        "stacks/dns"
        "stacks/observability"
        "stacks/ai-watchdog"
    )
    
    for stack_dir in "${stack_dirs[@]}"; do
        if [[ -d "$stack_dir" ]]; then
            local compose_file="$stack_dir/docker-compose.yml"
            if [[ -f "$compose_file" ]]; then
                log_pass "Legacy stack exists: $stack_dir"
                
                # Validate if possible (but don't fail if it has env var issues)
                if docker compose -f "$compose_file" config --quiet 2>/dev/null; then
                    log_info "Legacy $stack_dir compose is valid"
                else
                    log_warn "Legacy $stack_dir compose may need .env configuration"
                fi
            else
                log_warn "Legacy stack missing compose file: $stack_dir"
            fi
        else
            log_info "Legacy stack directory not found: $stack_dir (optional)"
        fi
    done
    
    return 0
}

# =============================================================================
# Test 9: Build Image Dry-Run
# =============================================================================
test_build_dry_run() {
    section "9. Build Dry-Run (Dockerfile validation)"
    
    cd "$REPO_ROOT" || exit 1
    
    # Check that we can at least parse the compose build contexts
    local build_services
    build_services=$(docker compose --profile "$PROFILE" config 2>/dev/null | grep -E "^\s+build:" -A 2 | grep "context:" | awk '{print $2}' || true)
    
    if [[ -n "$build_services" ]]; then
        log_pass "Build contexts are parseable"
        log_info "Build contexts: $build_services"
    else
        log_warn "No build contexts found (using pre-built images)"
    fi
    
    # Validate Dockerfile syntax for build contexts
    for context_dir in config/unbound config/keepalived; do
        if [[ -f "$context_dir/Dockerfile" ]]; then
            # Basic Dockerfile syntax check
            if grep -q "^FROM " "$context_dir/Dockerfile"; then
                log_pass "Dockerfile in $context_dir has valid FROM instruction"
            else
                log_fail "Dockerfile in $context_dir missing FROM instruction"
            fi
        fi
    done
    
    return 0
}

# =============================================================================
# Test 10: Deployment Scenario Validation
# =============================================================================
test_deployment_scenarios() {
    section "10. Deployment Scenario Validation"
    
    cd "$REPO_ROOT" || exit 1
    
    # Test single-node deployment scenario
    log_info "Testing single-node configuration..."
    if docker compose --profile dns-core config --quiet 2>/dev/null; then
        local service_list
        service_list=$(docker compose --profile dns-core config --services 2>/dev/null | tr '\n' ', ' | sed 's/,$//')
        log_pass "dns-core profile is valid (services: $service_list)"
    else
        log_fail "dns-core profile validation failed"
    fi
    
    # Test exporters profile
    log_info "Testing exporters configuration..."
    if docker compose --profile exporters config --quiet 2>/dev/null; then
        local exporter_list
        exporter_list=$(docker compose --profile exporters config --services 2>/dev/null | tr '\n' ', ' | sed 's/,$//')
        log_pass "exporters profile is valid (services: $exporter_list)"
    else
        log_warn "exporters profile may have issues"
    fi
    
    # Test combined profiles
    log_info "Testing combined profiles (dns-core + exporters)..."
    if docker compose --profile dns-core --profile exporters config --quiet 2>/dev/null; then
        log_pass "Combined profiles are valid"
    else
        log_warn "Combined profiles may have issues"
    fi
    
    return 0
}

# =============================================================================
# Summary
# =============================================================================
print_summary() {
    echo ""
    echo -e "${CYAN}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${CYAN}${BOLD}  DEPLOYMENT DRY-RUN SUMMARY${NC}"
    echo -e "${CYAN}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    
    local total=$((TESTS_PASSED + TESTS_FAILED + TESTS_WARNED))
    echo -e "  ${GREEN}Passed:${NC}   $TESTS_PASSED"
    echo -e "  ${YELLOW}Warnings:${NC} $TESTS_WARNED"
    echo -e "  ${RED}Failed:${NC}   $TESTS_FAILED"
    echo -e "  ${BLUE}Total:${NC}    $total"
    echo ""
    
    if [[ $TESTS_FAILED -eq 0 ]]; then
        if [[ $TESTS_WARNED -gt 0 ]]; then
            echo -e "${YELLOW}${BOLD}⚠️  Deployment configuration is VALID with warnings${NC}"
            echo ""
            echo "The system should deploy, but consider addressing the warnings."
        else
            echo -e "${GREEN}${BOLD}✅ Deployment configuration is VALID${NC}"
            echo ""
            echo "You can proceed with deployment:"
            echo "  1. Ensure .env is properly configured"
            echo "  2. Run: make up-core"
            echo "  3. Access Pi-hole at: http://<HOST_IP>/admin"
        fi
        return 0
    else
        echo -e "${RED}${BOLD}❌ Deployment configuration has ERRORS${NC}"
        echo ""
        echo "Please fix the failed tests before deploying."
        echo "Run with --verbose for more details."
        return 1
    fi
}

# =============================================================================
# Main
# =============================================================================
main() {
    echo ""
    echo -e "${CYAN}${BOLD}╔═══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}${BOLD}║     Orion Sentinel DNS HA - Deployment Dry-Run Test           ║${NC}"
    echo -e "${CYAN}${BOLD}╚═══════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "Testing profile: ${BOLD}$PROFILE${NC}"
    
    test_docker_available
    test_environment_config
    test_main_compose
    test_build_contexts
    test_scripts
    test_volume_mounts
    test_network_config
    test_legacy_stacks
    test_build_dry_run
    test_deployment_scenarios
    
    print_summary
}

main "$@"
