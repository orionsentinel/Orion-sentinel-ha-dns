#!/bin/bash
# Deployment readiness check script

echo "========================================"
echo "Deployment Readiness Check"
echo "========================================"
echo ""

GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

CHECKS_PASSED=0
CHECKS_FAILED=0

check_item() {
    if [ $1 -eq 0 ]; then
        echo -e "${GREEN}✓${NC} $2"
        ((CHECKS_PASSED++))
    else
        echo -e "${RED}✗${NC} $2"
        ((CHECKS_FAILED++))
    fi
}

echo "Checking Docker Compose configurations..."
echo ""

# Check if all required docker-compose files exist
check_item "$(test -f stacks/dns/docker-compose.yml && echo 0 || echo 1)" \
    "DNS stack docker-compose.yml exists"
    
check_item "$(test -f stacks/observability/docker-compose.yml && echo 0 || echo 1)" \
    "Observability stack docker-compose.yml exists"
    
check_item "$(test -f stacks/ai-watchdog/docker-compose.yml && echo 0 || echo 1)" \
    "AI-watchdog docker-compose.yml exists"

echo ""
echo "Checking Signal webhook integration..."
echo ""

# Check Signal webhook bridge files
check_item "$(test -f stacks/observability/signal-webhook-bridge/app.py && echo 0 || echo 1)" \
    "Signal webhook bridge app.py exists"
    
check_item "$(test -f stacks/observability/signal-webhook-bridge/Dockerfile && echo 0 || echo 1)" \
    "Signal webhook bridge Dockerfile exists"

# Check if configuration files have been updated
check_item "$(grep -q "signal-webhook-bridge" stacks/observability/alertmanager/alertmanager.yml && echo 0 || echo 1)" \
    "Alertmanager configured for Signal"
    
check_item "$(grep -q "send_signal_notification" stacks/ai-watchdog/app.py && echo 0 || echo 1)" \
    "AI-watchdog has Signal notification support"

echo ""
echo "Checking documentation..."
echo ""

check_item "$(grep -q "signal-cli-rest-api" README.md && echo 0 || echo 1)" \
    "README documents Signal notification setup"
    
check_item "$(test -f QA_TEST_RESULTS.md && echo 0 || echo 1)" \
    "QA test results document exists"

echo ""
echo "Checking environment configuration..."
echo ""

check_item "$(grep -q "SIGNAL_NUMBER" .env.example && echo 0 || echo 1)" \
    ".env.example has SIGNAL_NUMBER"
    
check_item "$(grep -q "SIGNAL_RECIPIENTS" .env.example && echo 0 || echo 1)" \
    ".env.example has SIGNAL_RECIPIENTS"

echo ""
echo "Checking Python dependencies..."
echo ""

# Verify requests library is in Dockerfile
check_item "$(grep -q "requests" stacks/observability/signal-webhook-bridge/Dockerfile && echo 0 || echo 1)" \
    "Signal bridge Dockerfile includes requests library"
    
check_item "$(grep -q "requests" stacks/ai-watchdog/Dockerfile && echo 0 || echo 1)" \
    "AI-watchdog Dockerfile includes requests library"

echo ""
echo "========================================"
echo "Deployment Readiness Summary"
echo "========================================"
echo -e "Checks Passed: ${GREEN}${CHECKS_PASSED}${NC}"
echo -e "Checks Failed: ${RED}${CHECKS_FAILED}${NC}"
echo "Total Checks: $((CHECKS_PASSED + CHECKS_FAILED))"
echo ""

if [ $CHECKS_FAILED -eq 0 ]; then
    echo -e "${GREEN}✓ System is ready for deployment!${NC}"
    echo ""
    echo "Next steps:"
    echo "1. Copy .env.example to .env"
    echo "2. Update .env with your SIGNAL_NUMBER and SIGNAL_RECIPIENTS"
    echo "3. Deploy the stack: cd stacks/observability && docker compose up -d"
    echo "4. Link Signal (one-time): docker exec -it signal-cli-rest-api signal-cli link -n 'RPi-DNS-Monitor'"
    echo "5. Test notification: curl -X POST http://192.168.8.250:8080/test -H 'Content-Type: application/json' -d '{\"message\":\"Test\"}'"
    echo ""
    exit 0
else
    echo -e "${RED}✗ System is not ready for deployment. Please fix the issues above.${NC}"
    exit 1
fi
