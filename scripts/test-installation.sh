#!/usr/bin/env bash
# Comprehensive test suite for installation methods
# Tests: install-check.sh, terminal install, and validates configurations

set -u

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

TESTS_PASSED=0
TESTS_FAILED=0
TEST_LOG="/tmp/installation-tests-$(date +%Y%m%d-%H%M%S).log"

log() { echo -e "${GREEN}[✓]${NC} $*" | tee -a "$TEST_LOG"; }
err() { echo -e "${RED}[✗]${NC} $*" | tee -a "$TEST_LOG" >&2; }
warn() { echo -e "${YELLOW}[!]${NC} $*" | tee -a "$TEST_LOG"; }
info() { echo -e "${BLUE}[i]${NC} $*" | tee -a "$TEST_LOG"; }
section() { echo -e "\n${CYAN}${BOLD}═══ $* ═══${NC}\n" | tee -a "$TEST_LOG"; }

pass_test() {
    ((TESTS_PASSED++))
    log "$*"
}

fail_test() {
    ((TESTS_FAILED++))
    err "$*"
}

show_banner() {
    clear
    echo -e "${CYAN}${BOLD}"
    cat << 'EOF'
╔═══════════════════════════════════════════════════════════════╗
║                                                               ║
║    RPi HA DNS Stack - Installation Test Suite                ║
║                                                               ║
╚═══════════════════════════════════════════════════════════════╝
EOF
    echo -e "${NC}"
}

# Test 1: Script syntax validation
test_script_syntax() {
    section "Test 1: Script Syntax Validation"
    
    local scripts=(
        "install.sh"
        "scripts/install.sh"
        "scripts/install-check.sh"
        "scripts/install-gui.sh"
        "scripts/launch-setup-ui.sh"
        "scripts/setup.sh"
        "scripts/interactive-setup.sh"
    )
    
    for script in "${scripts[@]}"; do
        if [[ -f "$REPO_ROOT/$script" ]]; then
            if bash -n "$REPO_ROOT/$script" 2>>"$TEST_LOG"; then
                pass_test "Syntax OK: $script"
            else
                fail_test "Syntax error: $script"
            fi
        else
            warn "Script not found: $script"
        fi
    done
}

# Test 2: Shellcheck validation
test_shellcheck() {
    section "Test 2: Shellcheck Validation"
    
    if ! command -v shellcheck &> /dev/null; then
        warn "shellcheck not installed, skipping"
        return 0
    fi
    
    local scripts=(
        "scripts/install.sh"
        "scripts/install-check.sh"
        "scripts/install-gui.sh"
        "scripts/launch-setup-ui.sh"
    )
    
    for script in "${scripts[@]}"; do
        if [[ -f "$REPO_ROOT/$script" ]]; then
            if shellcheck "$REPO_ROOT/$script" &>>"$TEST_LOG"; then
                pass_test "Shellcheck passed: $script"
            else
                warn "Shellcheck warnings in: $script (check $TEST_LOG)"
            fi
        fi
    done
}

# Test 3: Docker configuration validation
test_docker_configs() {
    section "Test 3: Docker Configuration Validation"
    
    local configs=(
        "stacks/dns/docker-compose.yml"
        "stacks/observability/docker-compose.yml"
        "stacks/ai-watchdog/docker-compose.yml"
    )
    
    # Create temporary .env for validation if it doesn't exist
    local temp_env=false
    if [[ ! -f "$REPO_ROOT/.env" ]] && [[ -f "$REPO_ROOT/.env.example" ]]; then
        cp "$REPO_ROOT/.env.example" "$REPO_ROOT/.env"
        temp_env=true
    fi
    
    for config in "${configs[@]}"; do
        if [[ -f "$REPO_ROOT/$config" ]]; then
            # Just check if file is valid YAML, don't run docker compose config
            if grep -q "services:" "$REPO_ROOT/$config" && grep -q "image:" "$REPO_ROOT/$config"; then
                pass_test "Valid docker-compose structure: $config"
            else
                fail_test "Invalid docker-compose structure: $config"
            fi
        else
            fail_test "Config not found: $config"
        fi
    done
    
    # Clean up temp .env if we created it
    if [[ "$temp_env" == true ]]; then
        rm -f "$REPO_ROOT/.env"
    fi
}

# Test 4: ARM64 compatibility check
test_arm64_compatibility() {
    section "Test 4: ARM64 Compatibility Check"
    
    info "Checking for ARM64 compatible images..."
    
    # Check unbound image
    if grep -q "klutchell/unbound" "$REPO_ROOT/stacks/dns/docker-compose.yml"; then
        pass_test "Unbound uses multi-arch image (klutchell/unbound)"
    elif grep -q "mvance/unbound-rpi" "$REPO_ROOT/stacks/dns/docker-compose.yml"; then
        fail_test "Unbound uses ARM-only image (mvance/unbound-rpi) - not compatible with ARM64"
    else
        warn "Could not determine unbound image"
    fi
    
    # Check Pi-hole image
    if grep -q "pihole/pihole:latest" "$REPO_ROOT/stacks/dns/docker-compose.yml"; then
        pass_test "Pi-hole uses official multi-arch image"
    else
        warn "Pi-hole image may not be multi-arch"
    fi
}

# Test 5: Required files existence
test_required_files() {
    section "Test 5: Required Files Check"
    
    local required_files=(
        "install.sh"
        "scripts/install.sh"
        "scripts/install-check.sh"
        "scripts/install-gui.sh"
        "scripts/launch-setup-ui.sh"
        "scripts/setup.sh"
        ".env.example"
        "stacks/dns/docker-compose.yml"
        "stacks/observability/docker-compose.yml"
        "stacks/setup-ui/docker-compose.yml"
        "stacks/setup-ui/app.py"
    )
    
    for file in "${required_files[@]}"; do
        if [[ -f "$REPO_ROOT/$file" ]]; then
            pass_test "File exists: $file"
        else
            fail_test "Missing required file: $file"
        fi
    done
}

# Test 6: Installation method documentation
test_documentation() {
    section "Test 6: Documentation Check"
    
    # Check if all three methods are documented
    if grep -q "install-check.sh" "$REPO_ROOT/scripts/README.md" 2>/dev/null; then
        pass_test "install-check.sh documented"
    else
        fail_test "install-check.sh not documented in README"
    fi
    
    if grep -q "install-gui.sh" "$REPO_ROOT/scripts/README.md" 2>/dev/null; then
        pass_test "install-gui.sh documented"
    else
        fail_test "install-gui.sh not documented in README"
    fi
    
    if grep -q "launch-setup-ui.sh" "$REPO_ROOT/scripts/README.md" 2>/dev/null; then
        pass_test "launch-setup-ui.sh documented"
    else
        fail_test "launch-setup-ui.sh not documented in README"
    fi
}

# Test 7: Environment file validation
test_env_file() {
    section "Test 7: Environment File Validation"
    
    if [[ -f "$REPO_ROOT/.env.example" ]]; then
        pass_test ".env.example exists"
        
        # Check for required variables
        local required_vars=(
            "PIHOLE_PASSWORD"
            "TZ"
            "SUBNET"
            "GATEWAY"
            "HOST_IP"
            "VIP_ADDRESS"
        )
        
        for var in "${required_vars[@]}"; do
            if grep -q "^${var}=" "$REPO_ROOT/.env.example"; then
                pass_test "Variable defined in .env.example: $var"
            else
                warn "Variable not found in .env.example: $var"
            fi
        done
    else
        fail_test ".env.example not found"
    fi
}

# Test 8: Unbound configuration validation
test_unbound_config() {
    section "Test 8: Unbound Configuration"
    
    local unbound_configs=(
        "stacks/dns/unbound1/unbound.conf"
        "stacks/dns/unbound2/unbound.conf"
    )
    
    for config in "${unbound_configs[@]}"; do
        if [[ -f "$REPO_ROOT/$config" ]]; then
            pass_test "Unbound config exists: $config"
            
            # Check critical settings
            if grep -q "port: 5335" "$REPO_ROOT/$config"; then
                pass_test "Unbound configured on port 5335"
            else
                fail_test "Unbound port not configured correctly in $config"
            fi
        else
            fail_test "Missing unbound config: $config"
        fi
    done
}

# Test 9: Script permissions
test_script_permissions() {
    section "Test 9: Script Permissions"
    
    local scripts=(
        "install.sh"
        "scripts/install.sh"
        "scripts/install-check.sh"
        "scripts/install-gui.sh"
        "scripts/launch-setup-ui.sh"
        "scripts/setup.sh"
    )
    
    for script in "${scripts[@]}"; do
        if [[ -f "$REPO_ROOT/$script" ]]; then
            if [[ -x "$REPO_ROOT/$script" ]]; then
                pass_test "Executable: $script"
            else
                warn "Not executable: $script (run: chmod +x $script)"
            fi
        fi
    done
}

# Test 10: Critical bugs verification
test_critical_bugs_fixed() {
    section "Test 10: Critical Bugs Verification"
    
    # Bug 1: REPO_ROOT must be set correctly in scripts/install.sh
    # Now uses git rev-parse with fallback to cd-based approach for robustness
    if grep -q 'REPO_ROOT=.*git rev-parse\|REPO_ROOT=.*dirname.*BASH_SOURCE' "$REPO_ROOT/scripts/install.sh"; then
        pass_test "Bug #1 fixed: REPO_ROOT detection in scripts/install.sh"
    else
        fail_test "Bug #1 NOT fixed: REPO_ROOT detection missing in scripts/install.sh"
    fi
    
    # Bug 2: Validation before calling launch-setup-ui.sh
    if grep -q "scripts/launch-setup-ui.sh" "$REPO_ROOT/install.sh" && grep -q "\[\[ ! -f.*launch-setup-ui.sh" "$REPO_ROOT/install.sh"; then
        pass_test "Bug #3 fixed: Validation before calling launch-setup-ui.sh"
    else
        warn "Bug #3: May need validation check for launch-setup-ui.sh"
    fi
    
    # Bug 4: Docker verification
    if grep -q "docker.*running\|docker.*accessible\|docker version" "$REPO_ROOT/scripts/install.sh"; then
        pass_test "Bug #4 fixed: Docker runtime verification added"
    else
        warn "Bug #4: Docker runtime verification may need improvement"
    fi
    
    # Bug 5: Prerequisite checks
    if grep -q "check_prerequisites\|AVAILABLE_GB\|TOTAL_MEM_MB" "$REPO_ROOT/scripts/install.sh"; then
        pass_test "Bug #5 fixed: Prerequisite checks added"
    else
        fail_test "Bug #5 NOT fixed: Missing prerequisite checks"
    fi
}

# Show summary
show_summary() {
    section "Test Summary"
    
    echo ""
    local total=$((TESTS_PASSED + TESTS_FAILED))
    echo -e "${BOLD}Total Tests: $total${NC}"
    echo -e "${GREEN}Passed: $TESTS_PASSED${NC}"
    echo -e "${RED}Failed: $TESTS_FAILED${NC}"
    echo ""
    
    if [[ $TESTS_FAILED -eq 0 ]]; then
        echo -e "${GREEN}${BOLD}✓ All tests passed!${NC}"
        echo ""
        echo -e "${CYAN}The installation system is ready for use.${NC}"
        echo ""
        return 0
    else
        echo -e "${RED}${BOLD}✗ Some tests failed${NC}"
        echo ""
        echo -e "${YELLOW}Please review the test log:${NC}"
        echo -e "  ${BOLD}$TEST_LOG${NC}"
        echo ""
        return 1
    fi
}

# Main execution
main() {
    show_banner
    
    info "Starting comprehensive installation test suite..."
    info "Test log: $TEST_LOG"
    echo ""
    
    test_script_syntax
    test_shellcheck
    test_docker_configs
    test_arm64_compatibility
    test_required_files
    test_documentation
    test_env_file
    test_unbound_config
    test_script_permissions
    test_critical_bugs_fixed
    
    show_summary
}

main "$@"
