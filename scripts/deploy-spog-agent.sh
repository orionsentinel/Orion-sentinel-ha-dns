#!/bin/bash
# deploy-spog-agent.sh
# Deploys Promtail log shipping agent for SPoG (Single Pane of Glass) mode
#
# Usage:
#   ./scripts/deploy-spog-agent.sh [pi-dns|pi-netsec] <dell-ip>
#
# Examples:
#   ./scripts/deploy-spog-agent.sh pi-dns 192.168.8.100
#   ./scripts/deploy-spog-agent.sh pi-netsec 192.168.8.100

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to display usage
usage() {
    echo "Usage: $0 [pi-dns|pi-netsec] <dell-coresrv-ip>"
    echo ""
    echo "Arguments:"
    echo "  Agent type:     pi-dns      - Deploy DNS log agent"
    echo "                  pi-netsec   - Deploy NetSec log agent"
    echo "  Dell IP:        IP address of Dell CoreSrv (e.g., 192.168.8.100)"
    echo ""
    echo "Examples:"
    echo "  $0 pi-dns 192.168.8.100"
    echo "  $0 pi-netsec 192.168.8.100"
    echo ""
    echo "For more information, see: docs/SPOG_INTEGRATION_GUIDE.md"
    exit 1
}

# Check arguments
if [ $# -ne 2 ]; then
    print_error "Invalid number of arguments"
    usage
fi

AGENT_TYPE=$1
DELL_IP=$2

# Validate agent type
if [[ "$AGENT_TYPE" != "pi-dns" && "$AGENT_TYPE" != "pi-netsec" ]]; then
    print_error "Invalid agent type: $AGENT_TYPE"
    usage
fi

# Validate IP address format
if ! [[ $DELL_IP =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
    print_error "Invalid IP address format: $DELL_IP"
    exit 1
fi

# Get script directory
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"
AGENT_DIR="$REPO_ROOT/stacks/agents/$AGENT_TYPE"

print_info "Deploying SPoG agent: $AGENT_TYPE"
print_info "Dell CoreSrv IP: $DELL_IP"
print_info "Agent directory: $AGENT_DIR"

# Check if agent directory exists
if [ ! -d "$AGENT_DIR" ]; then
    print_error "Agent directory not found: $AGENT_DIR"
    exit 1
fi

cd "$AGENT_DIR"

# Check if example config exists
if [ ! -f "promtail-config.example.yml" ]; then
    print_error "Example config not found: promtail-config.example.yml"
    exit 1
fi

# Create config from example if it doesn't exist
if [ ! -f "promtail-config.yml" ]; then
    print_info "Creating promtail-config.yml from example..."
    cp promtail-config.example.yml promtail-config.yml
    print_success "Created promtail-config.yml"
else
    print_warning "promtail-config.yml already exists. Skipping creation."
    read -p "Do you want to overwrite it? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        cp promtail-config.example.yml promtail-config.yml
        print_success "Overwrote promtail-config.yml"
    fi
fi

# Update Loki URL in config
print_info "Updating Loki URL in promtail-config.yml..."
LOKI_URL="http://$DELL_IP:3100"

# Use sed to update the Loki URL
if [[ "$OSTYPE" == "darwin"* ]]; then
    # macOS
    sed -i '' "s|url: http://[0-9.]*:3100|url: $LOKI_URL|g" promtail-config.yml
else
    # Linux
    sed -i "s|url: http://[0-9.]*:3100|url: $LOKI_URL|g" promtail-config.yml
fi

print_success "Updated Loki URL to: $LOKI_URL"

# Set environment variable
export LOKI_URL="$LOKI_URL"
print_info "Set LOKI_URL environment variable: $LOKI_URL"

# Check if Docker is running
if ! docker info > /dev/null 2>&1; then
    print_error "Docker is not running. Please start Docker and try again."
    exit 1
fi

# Check if docker-compose.yml exists
if [ ! -f "docker-compose.yml" ]; then
    print_error "docker-compose.yml not found in $AGENT_DIR"
    exit 1
fi

# Create network if it doesn't exist
if [[ "$AGENT_TYPE" == "pi-dns" ]]; then
    NETWORK_NAME="dns_net"
else
    NETWORK_NAME="nsm_net"
fi

if ! docker network inspect "$NETWORK_NAME" > /dev/null 2>&1; then
    print_warning "Network $NETWORK_NAME not found. Creating..."
    docker network create "$NETWORK_NAME"
    print_success "Created network: $NETWORK_NAME"
else
    print_info "Network $NETWORK_NAME already exists"
fi

# Test connectivity to Dell CoreSrv
print_info "Testing connectivity to Dell CoreSrv..."
if ping -c 1 -W 2 "$DELL_IP" > /dev/null 2>&1; then
    print_success "Dell CoreSrv is reachable at $DELL_IP"
else
    print_warning "Dell CoreSrv is not reachable at $DELL_IP"
    print_warning "Agent will still be deployed, but logs may not ship until connectivity is established"
    read -p "Continue anyway? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        print_info "Deployment cancelled"
        exit 0
    fi
fi

# Deploy the agent
print_info "Deploying $AGENT_TYPE agent..."
docker compose up -d

# Wait for container to start
sleep 3

# Check if container is running
CONTAINER_NAME="${AGENT_TYPE}-agent"
if docker ps | grep -q "$CONTAINER_NAME"; then
    print_success "Agent deployed successfully!"
    print_info "Container name: $CONTAINER_NAME"

    # Show logs
    print_info "Showing recent logs:"
    docker logs --tail 20 "$CONTAINER_NAME"

    echo ""
    print_success "Deployment complete!"
    echo ""
    print_info "Next steps:"
    echo "  1. Verify logs are shipping:"
    echo "     docker logs $CONTAINER_NAME"
    echo ""
    echo "  2. Check metrics endpoint:"
    echo "     curl http://localhost:9080/metrics"
    echo ""
    echo "  3. Query logs in Grafana on Dell CoreSrv:"
    if [[ "$AGENT_TYPE" == "pi-dns" ]]; then
        echo "     {host=\"pi-dns\"}"
    else
        echo "     {host=\"pi-netsec\"}"
    fi
    echo ""
    echo "For troubleshooting, see: docs/SPOG_INTEGRATION_GUIDE.md"
else
    print_error "Agent failed to start!"
    print_info "Showing logs for troubleshooting:"
    docker compose logs
    exit 1
fi
