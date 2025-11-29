#!/usr/bin/env bash
# =============================================================================
# Test Script for CLI Installer
# =============================================================================
# Tests the command-line installer for the HA DNS stack
# 
# Usage: bash scripts/test-cli-install.sh
# =============================================================================

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
CLI_INSTALL="$SCRIPT_DIR/cli-install.sh"

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
TEST_LOG="/tmp/cli-install-tests-$(date +%Y%m%d-%H%M%S).log"

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
    echo -e "${CYAN}${BOLD}"
    cat << 'EOF'
╔═══════════════════════════════════════════════════════════════╗
║                                                               ║
║    CLI Installer Test Suite                                   ║
║                                                               ║
╚═══════════════════════════════════════════════════════════════╝
EOF
    echo -e "${NC}"
}

# Test 1: Script exists and is executable
test_script_exists() {
    section "Test 1: Script Existence and Permissions"
    
    if [[ -f "$CLI_INSTALL" ]]; then
        pass_test "CLI installer script exists"
    else
        fail_test "CLI installer script not found: $CLI_INSTALL"
        return 1
    fi
    
    if [[ -x "$CLI_INSTALL" ]]; then
        pass_test "CLI installer script is executable"
    else
        fail_test "CLI installer script is not executable"
    fi
}

# Test 2: Script syntax validation
test_script_syntax() {
    section "Test 2: Script Syntax Validation"
    
    if bash -n "$CLI_INSTALL" 2>>"$TEST_LOG"; then
        pass_test "Script syntax is valid"
    else
        fail_test "Script has syntax errors"
    fi
}

# Test 3: Help option works
test_help_option() {
    section "Test 3: Help Option"
    
    local output
    output=$("$CLI_INSTALL" --help 2>&1)
    local exit_code=$?
    
    if [[ $exit_code -eq 0 ]]; then
        pass_test "Help option exits with code 0"
    else
        fail_test "Help option exits with code $exit_code"
    fi
    
    if echo "$output" | grep -q "USAGE"; then
        pass_test "Help output contains USAGE section"
    else
        fail_test "Help output missing USAGE section"
    fi
    
    if echo "$output" | grep -q "OPTIONS"; then
        pass_test "Help output contains OPTIONS section"
    else
        fail_test "Help output missing OPTIONS section"
    fi
    
    if echo "$output" | grep -q "EXAMPLES"; then
        pass_test "Help output contains EXAMPLES section"
    else
        fail_test "Help output missing EXAMPLES section"
    fi
    
    if echo "$output" | grep -q "single-pi-ha"; then
        pass_test "Help mentions single-pi-ha mode"
    else
        fail_test "Help missing single-pi-ha mode"
    fi
    
    if echo "$output" | grep -q "two-pi-ha"; then
        pass_test "Help mentions two-pi-ha mode"
    else
        fail_test "Help missing two-pi-ha mode"
    fi
}

# Test 4: Version option works
test_version_option() {
    section "Test 4: Version Option"
    
    local output
    output=$("$CLI_INSTALL" --version 2>&1)
    local exit_code=$?
    
    if [[ $exit_code -eq 0 ]]; then
        pass_test "Version option exits with code 0"
    else
        fail_test "Version option exits with code $exit_code"
    fi
    
    if echo "$output" | grep -qE "v[0-9]+\.[0-9]+\.[0-9]+"; then
        pass_test "Version output contains version number"
    else
        fail_test "Version output missing version number"
    fi
}

# Test 5: Invalid mode handling
test_invalid_mode() {
    section "Test 5: Invalid Mode Handling"
    
    local output
    output=$("$CLI_INSTALL" --mode invalid-mode --non-interactive 2>&1)
    local exit_code=$?
    
    if [[ $exit_code -ne 0 ]]; then
        pass_test "Invalid mode exits with non-zero code"
    else
        fail_test "Invalid mode should exit with non-zero code"
    fi
    
    if echo "$output" | grep -qi "invalid"; then
        pass_test "Invalid mode shows error message"
    else
        fail_test "Invalid mode should show error message"
    fi
}

# Test 6: Dry-run mode (single-pi-ha)
test_dry_run_single_pi() {
    section "Test 6: Dry-Run Mode (single-pi-ha)"
    
    local output
    output=$("$CLI_INSTALL" --mode single-pi-ha --dry-run --non-interactive --skip-validation 2>&1)
    local exit_code=$?
    
    if [[ $exit_code -eq 0 ]]; then
        pass_test "Dry-run single-pi-ha exits with code 0"
    else
        fail_test "Dry-run single-pi-ha exits with code $exit_code"
    fi
    
    if echo "$output" | grep -q "DRY-RUN"; then
        pass_test "Dry-run output mentions DRY-RUN"
    else
        fail_test "Dry-run output should mention DRY-RUN"
    fi
    
    if echo "$output" | grep -q "single-pi-ha"; then
        pass_test "Dry-run output mentions selected mode"
    else
        fail_test "Dry-run output should mention selected mode"
    fi
}

# Test 7: Dry-run mode (two-pi-ha)
test_dry_run_two_pi() {
    section "Test 7: Dry-Run Mode (two-pi-ha)"
    
    local output
    output=$("$CLI_INSTALL" --mode two-pi-ha --node-role MASTER --dry-run --non-interactive --skip-validation 2>&1)
    local exit_code=$?
    
    if [[ $exit_code -eq 0 ]]; then
        pass_test "Dry-run two-pi-ha MASTER exits with code 0"
    else
        fail_test "Dry-run two-pi-ha MASTER exits with code $exit_code"
    fi
    
    output=$("$CLI_INSTALL" --mode two-pi-ha --node-role BACKUP --dry-run --non-interactive --skip-validation 2>&1)
    exit_code=$?
    
    if [[ $exit_code -eq 0 ]]; then
        pass_test "Dry-run two-pi-ha BACKUP exits with code 0"
    else
        fail_test "Dry-run two-pi-ha BACKUP exits with code $exit_code"
    fi
}

# Test 8: Configuration generation
test_config_generation() {
    section "Test 8: Configuration Generation"
    
    # Create a temp directory for testing
    local temp_dir
    temp_dir=$(mktemp -d)
    local test_env="$temp_dir/.env"
    
    # Backup current .env if exists
    local original_env=""
    if [[ -f "$REPO_ROOT/.env" ]]; then
        original_env=$(cat "$REPO_ROOT/.env")
    fi
    
    # Test config generation with dry-run
    local output
    output=$("$CLI_INSTALL" --mode single-pi-ha \
        --host-ip 192.168.1.100 \
        --vip 192.168.1.200 \
        --pihole-password "TestPass123" \
        --grafana-password "GrafanaPass456" \
        --dry-run --non-interactive --skip-validation 2>&1)
    
    if echo "$output" | grep -q "HOST_IP=192.168.1.100"; then
        pass_test "Config generation includes HOST_IP"
    else
        fail_test "Config generation missing HOST_IP"
    fi
    
    if echo "$output" | grep -q "VIP_ADDRESS=192.168.1.200"; then
        pass_test "Config generation includes VIP_ADDRESS"
    else
        fail_test "Config generation missing VIP_ADDRESS"
    fi
    
    if echo "$output" | grep -q "PIHOLE_PASSWORD=TestPass123"; then
        pass_test "Config generation includes PIHOLE_PASSWORD"
    else
        fail_test "Config generation missing PIHOLE_PASSWORD"
    fi
    
    if echo "$output" | grep -q "DEPLOY_MODE=single-pi-ha"; then
        pass_test "Config generation includes DEPLOY_MODE"
    else
        fail_test "Config generation missing DEPLOY_MODE"
    fi
    
    # Restore original .env if it existed
    if [[ -n "$original_env" ]]; then
        echo "$original_env" > "$REPO_ROOT/.env"
    fi
    
    # Cleanup
    rm -rf "$temp_dir"
}

# Test 9: CLI parameter validation
test_parameter_validation() {
    section "Test 9: CLI Parameter Validation"
    
    # Test invalid node role
    local output
    output=$("$CLI_INSTALL" --mode two-pi-ha --node-role INVALID --non-interactive 2>&1)
    local exit_code=$?
    
    if [[ $exit_code -ne 0 ]]; then
        pass_test "Invalid node role is rejected"
    else
        fail_test "Invalid node role should be rejected"
    fi
    
    # Test unknown option
    output=$("$CLI_INSTALL" --unknown-option 2>&1)
    exit_code=$?
    
    if [[ $exit_code -ne 0 ]]; then
        pass_test "Unknown option is rejected"
    else
        fail_test "Unknown option should be rejected"
    fi
}

# Test 10: All deployment modes dry-run
test_all_modes() {
    section "Test 10: All Deployment Modes"
    
    local modes=("single-pi-ha" "two-pi-simple" "two-pi-ha")
    
    for mode in "${modes[@]}"; do
        local output
        output=$("$CLI_INSTALL" --mode "$mode" --dry-run --non-interactive --skip-validation 2>&1)
        local exit_code=$?
        
        if [[ $exit_code -eq 0 ]]; then
            pass_test "Mode '$mode' dry-run succeeds"
        else
            fail_test "Mode '$mode' dry-run failed with code $exit_code"
        fi
    done
}

# Test 11: Network configuration options
test_network_options() {
    section "Test 11: Network Configuration Options"
    
    local output
    output=$("$CLI_INSTALL" --mode single-pi-ha \
        --host-ip 10.0.0.50 \
        --vip 10.0.0.100 \
        --interface wlan0 \
        --subnet 10.0.0.0/24 \
        --gateway 10.0.0.1 \
        --timezone "America/New_York" \
        --dry-run --non-interactive --skip-validation 2>&1)
    local exit_code=$?
    
    if [[ $exit_code -eq 0 ]]; then
        pass_test "Custom network config accepts all parameters"
    else
        fail_test "Custom network config failed with code $exit_code"
    fi
    
    if echo "$output" | grep -q "Host IP:.*10.0.0.50"; then
        pass_test "Host IP parameter is applied"
    else
        fail_test "Host IP parameter not applied"
    fi
    
    if echo "$output" | grep -q "VIP Address:.*10.0.0.100"; then
        pass_test "VIP parameter is applied"
    else
        fail_test "VIP parameter not applied"
    fi
}

# Test 12: Password options
test_password_options() {
    section "Test 12: Password Options"
    
    local output
    output=$("$CLI_INSTALL" --mode single-pi-ha \
        --pihole-password "SecurePass123!" \
        --grafana-password "GrafanaPass456!" \
        --vrrp-password "VrrpPass789!" \
        --dry-run --non-interactive --skip-validation 2>&1)
    local exit_code=$?
    
    if [[ $exit_code -eq 0 ]]; then
        pass_test "Password parameters accepted"
    else
        fail_test "Password parameters failed with code $exit_code"
    fi
    
    # Verify passwords appear in config output
    if echo "$output" | grep -q "PIHOLE_PASSWORD=SecurePass123!"; then
        pass_test "Pi-hole password is set correctly"
    else
        fail_test "Pi-hole password not set correctly"
    fi
}

# Test 13: Generate config only mode
test_generate_config_mode() {
    section "Test 13: Generate Config Only Mode"
    
    # Backup current .env
    local backup_env=""
    if [[ -f "$REPO_ROOT/.env" ]]; then
        backup_env=$(cat "$REPO_ROOT/.env")
    fi
    
    local output
    output=$("$CLI_INSTALL" --mode single-pi-ha \
        --generate-config \
        --pihole-password "TestPass123" \
        --non-interactive --skip-validation 2>&1)
    local exit_code=$?
    
    if [[ $exit_code -eq 0 ]]; then
        pass_test "Generate config mode exits with code 0"
    else
        fail_test "Generate config mode exits with code $exit_code"
    fi
    
    if echo "$output" | grep -qi "config.*generated\|configuration.*saved"; then
        pass_test "Generate config mode shows success message"
    else
        fail_test "Generate config mode should show success message"
    fi
    
    # Verify .env was created
    if [[ -f "$REPO_ROOT/.env" ]]; then
        pass_test ".env file was created"
        
        # Check file contents
        if grep -q "DEPLOY_MODE=single-pi-ha" "$REPO_ROOT/.env"; then
            pass_test ".env contains correct mode"
        else
            fail_test ".env missing correct mode"
        fi
    else
        fail_test ".env file was not created"
    fi
    
    # Restore original .env
    if [[ -n "$backup_env" ]]; then
        echo "$backup_env" > "$REPO_ROOT/.env"
    else
        rm -f "$REPO_ROOT/.env"
    fi
}

# Test 14: Script shebang and bash features
test_bash_compatibility() {
    section "Test 14: Bash Compatibility"
    
    # Check shebang
    local shebang
    shebang=$(head -1 "$CLI_INSTALL")
    
    if [[ "$shebang" == "#!/usr/bin/env bash" ]] || [[ "$shebang" == "#!/bin/bash" ]]; then
        pass_test "Script has valid bash shebang"
    else
        fail_test "Script missing valid bash shebang"
    fi
    
    # Check for set -u (undefined variable check)
    if grep -q "set -u" "$CLI_INSTALL"; then
        pass_test "Script uses 'set -u' for undefined variable checking"
    else
        warn "Script does not use 'set -u'"
    fi
}

# Test 15: Verbose mode
test_verbose_mode() {
    section "Test 15: Verbose Mode"
    
    local output
    output=$("$CLI_INSTALL" --mode single-pi-ha \
        --verbose --dry-run --non-interactive --skip-validation 2>&1)
    local exit_code=$?
    
    if [[ $exit_code -eq 0 ]]; then
        pass_test "Verbose mode runs successfully"
    else
        fail_test "Verbose mode failed with code $exit_code"
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
        echo -e "${CYAN}The CLI installer is ready for use.${NC}"
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
    
    info "Starting CLI installer test suite..."
    info "Test log: $TEST_LOG"
    echo ""
    
    test_script_exists || exit 1
    test_script_syntax
    test_help_option
    test_version_option
    test_invalid_mode
    test_dry_run_single_pi
    test_dry_run_two_pi
    test_config_generation
    test_parameter_validation
    test_all_modes
    test_network_options
    test_password_options
    test_generate_config_mode
    test_bash_compatibility
    test_verbose_mode
    
    show_summary
}

main "$@"
