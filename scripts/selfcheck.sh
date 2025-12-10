#!/usr/bin/env bash
# selfcheck.sh - Validate configuration for Orion Sentinel HA DNS
#
# This script validates:
# 1. promtail/config.yml is valid YAML
# 2. pihole/var-log is a directory (not a file)
# 3. .env.example contains required variables
# 4. Bootstrap directories exist
#
# Run this before deploying to catch configuration issues early.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(dirname "$SCRIPT_DIR")"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Use declare -i for explicit integer type
declare -i ERRORS=0
declare -i WARNINGS=0

echo "Running Orion Sentinel HA DNS self-check..."
echo ""

# Check 1: Validate promtail/config.yml is valid YAML
echo -n "Checking promtail/config.yml... "
if [ -f "$REPO_DIR/promtail/config.yml" ]; then
    # Use python to validate YAML if available, otherwise basic syntax check
    if command -v python3 &>/dev/null; then
        if python3 -c "import yaml; yaml.safe_load(open('$REPO_DIR/promtail/config.yml'))" 2>/dev/null; then
            echo -e "${GREEN}✓ Valid YAML${NC}"
        else
            echo -e "${RED}✗ Invalid YAML${NC}"
            ERRORS=$((ERRORS + 1))
        fi
    elif command -v python &>/dev/null; then
        if python -c "import yaml; yaml.safe_load(open('$REPO_DIR/promtail/config.yml'))" 2>/dev/null; then
            echo -e "${GREEN}✓ Valid YAML${NC}"
        else
            echo -e "${RED}✗ Invalid YAML (python check failed)${NC}"
            ERRORS=$((ERRORS + 1))
        fi
    else
        # Basic syntax check without python - just verify file has basic YAML structure
        # This is a fallback check when Python/PyYAML is unavailable and may produce
        # false positives/negatives. Manual validation is recommended if issues arise.
        if grep -qE '^[[:space:]]*-[[:space:]]+[^-]' "$REPO_DIR/promtail/config.yml" && \
           grep -qE '^[a-zA-Z]' "$REPO_DIR/promtail/config.yml"; then
            echo -e "${YELLOW}⚠ File exists (no YAML validator available)${NC}"
            WARNINGS=$((WARNINGS + 1))
        else
            echo -e "${RED}✗ File appears malformed${NC}"
            ERRORS=$((ERRORS + 1))
        fi
    fi
else
    echo -e "${RED}✗ File not found${NC}"
    ERRORS=$((ERRORS + 1))
fi

# Check 2: Verify pihole/var-log is a directory
echo -n "Checking pihole/var-log... "
if [ -d "$REPO_DIR/pihole/var-log" ]; then
    # Also check that pihole.log is not a directory
    if [ -e "$REPO_DIR/pihole/var-log/pihole.log" ] && [ -d "$REPO_DIR/pihole/var-log/pihole.log" ]; then
        echo -e "${RED}✗ pihole.log exists as directory (will cause errors)${NC}"
        echo "  Fix: rm -rf $REPO_DIR/pihole/var-log/pihole.log && touch $REPO_DIR/pihole/var-log/pihole.log"
        ERRORS=$((ERRORS + 1))
    else
        echo -e "${GREEN}✓ Directory exists${NC}"
    fi
else
    echo -e "${YELLOW}⚠ Directory not found (run ./scripts/bootstrap_dirs.sh)${NC}"
    WARNINGS=$((WARNINGS + 1))
fi

# Check 3: Verify required directories exist
echo -n "Checking pihole/etc-pihole... "
if [ -d "$REPO_DIR/pihole/etc-pihole" ]; then
    echo -e "${GREEN}✓ Directory exists${NC}"
else
    echo -e "${YELLOW}⚠ Directory not found${NC}"
    WARNINGS=$((WARNINGS + 1))
fi

echo -n "Checking pihole/etc-dnsmasq.d... "
if [ -d "$REPO_DIR/pihole/etc-dnsmasq.d" ]; then
    echo -e "${GREEN}✓ Directory exists${NC}"
else
    echo -e "${YELLOW}⚠ Directory not found${NC}"
    WARNINGS=$((WARNINGS + 1))
fi

echo -n "Checking keepalived/config... "
if [ -d "$REPO_DIR/keepalived/config" ]; then
    echo -e "${GREEN}✓ Directory exists${NC}"
else
    echo -e "${YELLOW}⚠ Directory not found${NC}"
    WARNINGS=$((WARNINGS + 1))
fi

# Check 4: Verify .env.example contains required variables
echo -n "Checking .env.example for LOKI_URL... "
if grep -q "^LOKI_URL=" "$REPO_DIR/.env.example" 2>/dev/null; then
    # Verify it has the full path
    if grep -qE "^LOKI_URL=.*loki/api/v1/push" "$REPO_DIR/.env.example"; then
        echo -e "${GREEN}✓ Found with full path${NC}"
    else
        echo -e "${YELLOW}⚠ Found but missing /loki/api/v1/push path${NC}"
        WARNINGS=$((WARNINGS + 1))
    fi
else
    echo -e "${RED}✗ Not found${NC}"
    ERRORS=$((ERRORS + 1))
fi

echo -n "Checking .env.example for VIP_ADDRESS... "
if grep -q "^VIP_ADDRESS=" "$REPO_DIR/.env.example" 2>/dev/null; then
    echo -e "${GREEN}✓ Found${NC}"
else
    echo -e "${RED}✗ Not found${NC}"
    ERRORS=$((ERRORS + 1))
fi

echo -n "Checking .env.example for VRRP_PASSWORD... "
if grep -q "^VRRP_PASSWORD=" "$REPO_DIR/.env.example" 2>/dev/null; then
    echo -e "${GREEN}✓ Found${NC}"
else
    echo -e "${RED}✗ Not found${NC}"
    ERRORS=$((ERRORS + 1))
fi

echo -n "Checking .env.example for NODE_NAME... "
if grep -q "^NODE_NAME=" "$REPO_DIR/.env.example" 2>/dev/null; then
    echo -e "${GREEN}✓ Found${NC}"
else
    echo -e "${YELLOW}⚠ Not found${NC}"
    WARNINGS=$((WARNINGS + 1))
fi

echo -n "Checking .env.example for NETWORK_INTERFACE... "
if grep -q "^NETWORK_INTERFACE=" "$REPO_DIR/.env.example" 2>/dev/null; then
    echo -e "${GREEN}✓ Found${NC}"
else
    echo -e "${RED}✗ Not found${NC}"
    ERRORS=$((ERRORS + 1))
fi

# Check 5: Verify compose.yml has pihole var-log volume
echo -n "Checking compose.yml for pihole var-log volume... "
if grep -q "./pihole/var-log:/var/log/pihole" "$REPO_DIR/compose.yml" 2>/dev/null; then
    echo -e "${GREEN}✓ Volume mount configured${NC}"
else
    echo -e "${RED}✗ Volume mount missing${NC}"
    ERRORS=$((ERRORS + 1))
fi

# Check 6: Verify compose.yml promtail has -config.expand-env=true
echo -n "Checking compose.yml for promtail config.expand-env... "
if grep -qE '\-config\.expand-env.*true' "$REPO_DIR/compose.yml" 2>/dev/null; then
    echo -e "${GREEN}✓ Environment expansion enabled${NC}"
else
    echo -e "${YELLOW}⚠ -config.expand-env=true not found${NC}"
    WARNINGS=$((WARNINGS + 1))
fi

# Summary
echo ""
echo "=========================================="
if [ $ERRORS -eq 0 ] && [ $WARNINGS -eq 0 ]; then
    echo -e "${GREEN}All checks passed!${NC}"
    echo ""
    echo "Ready to deploy. Run:"
    echo "  ./scripts/bootstrap_dirs.sh"
    echo "  docker compose --profile <profile> up -d"
    exit 0
elif [ $ERRORS -eq 0 ]; then
    echo -e "${YELLOW}Completed with $WARNINGS warning(s)${NC}"
    echo ""
    echo "Consider running ./scripts/bootstrap_dirs.sh to fix warnings."
    exit 0
else
    echo -e "${RED}Found $ERRORS error(s) and $WARNINGS warning(s)${NC}"
    echo ""
    echo "Fix the errors above before deploying."
    exit 1
fi
