#!/usr/bin/env bash
# Launch script for Web Setup UI
# Provides a graphical web interface for installation and configuration

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
SETUP_UI_DIR="$REPO_ROOT/stacks/setup-ui"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m' # No Color

log() { echo -e "${GREEN}[setup-ui]${NC} $*"; }
warn() { echo -e "${YELLOW}[setup-ui][WARNING]${NC} $*"; }
err() { echo -e "${RED}[setup-ui][ERROR]${NC} $*" >&2; }
info() { echo -e "${BLUE}[setup-ui][INFO]${NC} $*"; }

show_banner() {
    clear
    echo -e "${CYAN}${BOLD}"
    cat << 'EOF'
╔═══════════════════════════════════════════════════════════════╗
║                                                               ║
║    RPi High Availability DNS Stack - Web Setup UI            ║
║                                                               ║
╚═══════════════════════════════════════════════════════════════╝
EOF
    echo -e "${NC}"
}

check_docker() {
    if ! command -v docker &> /dev/null; then
        err "Docker is not installed"
        err "Please install Docker first: curl -fsSL https://get.docker.com | sh"
        exit 1
    fi
    
    if ! docker compose version &> /dev/null; then
        err "Docker Compose is not installed"
        err "Please install Docker Compose: sudo apt install docker-compose-plugin"
        exit 1
    fi
    
    # Check if Docker daemon is running
    if ! docker info &> /dev/null; then
        err "Docker daemon is not running"
        err "Please start Docker: sudo systemctl start docker"
        exit 1
    fi
    log "Docker is installed and running"
}

check_python() {
    if ! command -v python3 &> /dev/null; then
        err "Python 3 is not installed"
        err "Please install Python 3: sudo apt install python3"
        exit 1
    fi
    log "Python 3 is installed"
}

check_port() {
    local port=5555
    if netstat -tuln 2>/dev/null | grep -q ":${port} " || ss -tuln 2>/dev/null | grep -q ":${port} "; then
        warn "Port ${port} is already in use"
        warn "The setup UI may not start correctly"
        info "You can stop any process using port ${port} with: sudo lsof -ti:${port} | xargs kill -9"
        return 1
    fi
    log "Port ${port} is available"
    return 0
}

check_setup_ui_files() {
    if [[ ! -d "$SETUP_UI_DIR" ]]; then
        err "Setup UI directory not found: $SETUP_UI_DIR"
        err "The repository may be incomplete"
        exit 1
    fi
    
    if [[ ! -f "$SETUP_UI_DIR/docker-compose.yml" ]]; then
        err "Setup UI docker-compose.yml not found"
        err "The repository may be incomplete"
        exit 1
    fi
    log "Setup UI files are present"
}

start_ui() {
    log "Starting Web Setup UI..."
    
    cd "$SETUP_UI_DIR"
    
    # Check if container is already running
    if docker compose ps 2>/dev/null | grep -q "rpi-dns-setup-ui.*Up"; then
        warn "Setup UI is already running"
        info "Restarting to apply any changes..."
        docker compose restart
    else
        # Start the container
        if ! docker compose up -d; then
            err "Failed to start the setup UI"
            err "Check Docker logs: cd $SETUP_UI_DIR && docker compose logs"
            exit 1
        fi
    fi
    
    # Wait for the service to be ready
    log "Waiting for service to be ready..."
    local retries=10
    local count=0
    while [[ $count -lt $retries ]]; do
        if curl -s http://localhost:5555 >/dev/null 2>&1; then
            break
        fi
        sleep 1
        ((count++))
    done
    
    if [[ $count -eq $retries ]]; then
        warn "Setup UI may not be fully ready yet"
        info "Give it a few more seconds, then check http://localhost:5555"
    fi
    
    # Get the host IP
    HOST_IP=$(hostname -I | awk '{print $1}')
    
    echo ""
    echo -e "${GREEN}${BOLD}✓ Web Setup UI is now running!${NC}"
    echo ""
    echo -e "${CYAN}Access the setup wizard at:${NC}"
    echo -e "  ${BOLD}http://localhost:5555${NC}"
    echo -e "  ${BOLD}http://${HOST_IP}:5555${NC}"
    echo ""
    echo -e "${YELLOW}To stop the UI:${NC}"
    echo -e "  ${BOLD}bash scripts/launch-setup-ui.sh stop${NC}"
    echo ""
    echo -e "${YELLOW}To view logs:${NC}"
    echo -e "  ${BOLD}bash scripts/launch-setup-ui.sh logs${NC}"
    echo ""
}

stop_ui() {
    log "Stopping Web Setup UI..."
    cd "$SETUP_UI_DIR"
    docker compose down
    log "Web Setup UI stopped"
}

show_logs() {
    cd "$SETUP_UI_DIR"
    docker compose logs -f
}

show_status() {
    cd "$SETUP_UI_DIR"
    if docker compose ps | grep -q "rpi-dns-setup-ui.*Up"; then
        log "Web Setup UI is running"
        docker compose ps
    else
        warn "Web Setup UI is not running"
    fi
}

show_help() {
    cat << EOF
${BOLD}Usage:${NC}
  bash scripts/launch-setup-ui.sh [COMMAND]

${BOLD}Commands:${NC}
  start       Start the Web Setup UI (default)
  stop        Stop the Web Setup UI
  restart     Restart the Web Setup UI
  logs        Show logs from the Web Setup UI
  status      Show status of the Web Setup UI
  help        Show this help message

${BOLD}Examples:${NC}
  bash scripts/launch-setup-ui.sh              # Start the UI
  bash scripts/launch-setup-ui.sh stop         # Stop the UI
  bash scripts/launch-setup-ui.sh logs         # View logs

EOF
}

main() {
    show_banner
    check_docker
    check_python
    check_setup_ui_files
    check_port
    
    local command="${1:-start}"
    
    case "$command" in
        start)
            start_ui
            ;;
        stop)
            stop_ui
            ;;
        restart)
            stop_ui
            sleep 2
            start_ui
            ;;
        logs)
            show_logs
            ;;
        status)
            show_status
            ;;
        help|--help|-h)
            show_help
            ;;
        *)
            err "Unknown command: $command"
            echo ""
            show_help
            exit 1
            ;;
    esac
}

main "$@"
