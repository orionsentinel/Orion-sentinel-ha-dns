#!/bin/bash
# Signal Webhook Integration QA Test Script

echo "========================================"
echo "Signal Webhook Integration QA Tests"
echo "========================================"
echo ""

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Test results tracking
TESTS_PASSED=0
TESTS_FAILED=0

# Function to print test result
print_result() {
    if [ $1 -eq 0 ]; then
        echo -e "${GREEN}✓ PASS${NC}: $2"
        ((TESTS_PASSED++))
    else
        echo -e "${RED}✗ FAIL${NC}: $2"
        ((TESTS_FAILED++))
    fi
}

echo "Test 1: Check if signal-webhook-bridge service is defined"
if grep -q "signal-webhook-bridge" /home/runner/work/rpi-ha-dns-stack/rpi-ha-dns-stack/stacks/observability/docker-compose.yml; then
    print_result 0 "signal-webhook-bridge service is defined in docker-compose.yml"
else
    print_result 1 "signal-webhook-bridge service is NOT defined in docker-compose.yml"
fi
echo ""

echo "Test 2: Check if Signal webhook bridge app.py exists"
if [ -f "/home/runner/work/rpi-ha-dns-stack/rpi-ha-dns-stack/stacks/observability/signal-webhook-bridge/app.py" ]; then
    print_result 0 "Signal webhook bridge app.py exists"
else
    print_result 1 "Signal webhook bridge app.py does NOT exist"
fi
echo ""

echo "Test 3: Check if Signal webhook bridge Dockerfile exists"
if [ -f "/home/runner/work/rpi-ha-dns-stack/rpi-ha-dns-stack/stacks/observability/signal-webhook-bridge/Dockerfile" ]; then
    print_result 0 "Signal webhook bridge Dockerfile exists"
else
    print_result 1 "Signal webhook bridge Dockerfile does NOT exist"
fi
echo ""

echo "Test 4: Check if alertmanager.yml references signal-webhook-bridge"
if grep -q "signal-webhook-bridge:8080" /home/runner/work/rpi-ha-dns-stack/rpi-ha-dns-stack/stacks/observability/alertmanager/alertmanager.yml; then
    print_result 0 "alertmanager.yml correctly references signal-webhook-bridge"
else
    print_result 1 "alertmanager.yml does NOT reference signal-webhook-bridge"
fi
echo ""

echo "Test 5: Check if .env.example has SIGNAL_API_KEY"
if grep -q "SIGNAL_API_KEY" /home/runner/work/rpi-ha-dns-stack/rpi-ha-dns-stack/.env.example; then
    print_result 0 ".env.example contains SIGNAL_API_KEY"
else
    print_result 1 ".env.example does NOT contain SIGNAL_API_KEY"
fi
echo ""

echo "Test 6: Check if AI-watchdog has Signal notification support"
if grep -q "send_signal_notification" /home/runner/work/rpi-ha-dns-stack/rpi-ha-dns-stack/stacks/ai-watchdog/app.py; then
    print_result 0 "AI-watchdog has Signal notification support"
else
    print_result 1 "AI-watchdog does NOT have Signal notification support"
fi
echo ""

echo "Test 7: Validate Signal webhook bridge Python syntax"
if python3 -m py_compile /home/runner/work/rpi-ha-dns-stack/rpi-ha-dns-stack/stacks/observability/signal-webhook-bridge/app.py 2>/dev/null; then
    print_result 0 "Signal webhook bridge Python syntax is valid"
else
    print_result 1 "Signal webhook bridge Python syntax has errors"
fi
echo ""

echo "Test 8: Validate AI-watchdog Python syntax"
if python3 -m py_compile /home/runner/work/rpi-ha-dns-stack/rpi-ha-dns-stack/stacks/ai-watchdog/app.py 2>/dev/null; then
    print_result 0 "AI-watchdog Python syntax is valid"
else
    print_result 1 "AI-watchdog Python syntax has errors"
fi
echo ""

echo "Test 9: Check if docker-compose files are valid YAML"
docker compose -f /home/runner/work/rpi-ha-dns-stack/rpi-ha-dns-stack/stacks/observability/docker-compose.yml config > /dev/null 2>&1
if [ $? -eq 0 ]; then
    print_result 0 "observability/docker-compose.yml is valid YAML"
else
    print_result 1 "observability/docker-compose.yml has YAML errors"
fi
echo ""

docker compose -f /home/runner/work/rpi-ha-dns-stack/rpi-ha-dns-stack/stacks/ai-watchdog/docker-compose.yml config > /dev/null 2>&1
if [ $? -eq 0 ]; then
    print_result 0 "ai-watchdog/docker-compose.yml is valid YAML"
else
    print_result 1 "ai-watchdog/docker-compose.yml has YAML errors"
fi
echo ""

echo "Test 10: Check if README mentions Signal notifications"
if grep -q "Signal" /home/runner/work/rpi-ha-dns-stack/rpi-ha-dns-stack/README.md; then
    print_result 0 "README.md mentions Signal notifications"
else
    print_result 1 "README.md does NOT mention Signal notifications"
fi
echo ""

echo "========================================"
echo "Test Summary"
echo "========================================"
echo -e "Tests Passed: ${GREEN}${TESTS_PASSED}${NC}"
echo -e "Tests Failed: ${RED}${TESTS_FAILED}${NC}"
echo "Total Tests: $((TESTS_PASSED + TESTS_FAILED))"
echo ""

if [ $TESTS_FAILED -eq 0 ]; then
    echo -e "${GREEN}All tests passed! ✓${NC}"
    exit 0
else
    echo -e "${RED}Some tests failed. Please review.${NC}"
    exit 1
fi
