#!/usr/bin/env bash
# Update script for rpi-ha-dns-stack
# Safely updates the stack from git repository while preserving local configuration

set -u
IFS=$'\n\t'

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENV_FILE="$REPO_ROOT/.env"
BACKUP_DIR="$REPO_ROOT/.backups"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log() { echo -e "${GREEN}[update]${NC} $*"; }
warn() { echo -e "${YELLOW}[update][WARNING]${NC} $*"; }
err() { echo -e "${RED}[update][ERROR]${NC} $*" >&2; }
info() { echo -e "${BLUE}[update][INFO]${NC} $*"; }

check_prerequisites() {
    log "Checking prerequisites..."
    
    if ! command -v git &> /dev/null; then
        err "git is not installed. Please install git first."
        exit 1
    fi
    
    if ! command -v docker &> /dev/null; then
        err "docker is not installed. Please install docker first."
        exit 1
    fi
    
    if ! docker compose version &> /dev/null; then
        err "docker compose plugin is not installed."
        exit 1
    fi
    
    if [[ ! -d "$REPO_ROOT/.git" ]]; then
        err "This directory is not a git repository."
        err "Please clone the repository using: git clone <repo-url>"
        exit 1
    fi
}

backup_config() {
    log "Backing up current configuration..."
    
    mkdir -p "$BACKUP_DIR"
    BACKUP_TIMESTAMP=$(date +%Y%m%d_%H%M%S)
    
    # Backup .env file if it exists
    if [[ -f "$ENV_FILE" ]]; then
        cp "$ENV_FILE" "$BACKUP_DIR/.env.backup.$BACKUP_TIMESTAMP"
        info "Backed up .env to: $BACKUP_DIR/.env.backup.$BACKUP_TIMESTAMP"
    fi
    
    # Backup docker-compose.override.yml files if they exist
    for stack_dir in "$REPO_ROOT"/stacks/*/; do
        if [[ -f "${stack_dir}docker-compose.override.yml" ]]; then
            stack_name=$(basename "$stack_dir")
            cp "${stack_dir}docker-compose.override.yml" "$BACKUP_DIR/${stack_name}-override.backup.$BACKUP_TIMESTAMP"
            info "Backed up ${stack_name} override to: $BACKUP_DIR/${stack_name}-override.backup.$BACKUP_TIMESTAMP"
        fi
    done
    
    echo
}

check_git_status() {
    log "Checking git repository status..."
    
    cd "$REPO_ROOT" || exit
    
    # Check for uncommitted changes
    if [[ -n $(git status --porcelain) ]]; then
        warn "You have uncommitted changes in the repository:"
        git status --short
        echo
        read -r -p "Continue with update? This may overwrite local changes. (y/N): " continue_choice
        if [[ ! "$continue_choice" =~ ^[Yy]$ ]]; then
            log "Update cancelled by user"
            exit 0
        fi
    fi
    
    # Get current branch
    CURRENT_BRANCH=$(git branch --show-current)
    info "Current branch: $CURRENT_BRANCH"
    echo
}

pull_updates() {
    log "Pulling latest changes from repository..."
    
    cd "$REPO_ROOT" || exit
    
    # Fetch updates
    if ! git fetch origin; then
        err "Failed to fetch updates from remote repository"
        exit 1
    fi
    
    # Check if there are updates
    LOCAL_COMMIT=$(git rev-parse HEAD)
    REMOTE_COMMIT=$(git rev-parse "origin/$(git branch --show-current)")
    
    if [[ "$LOCAL_COMMIT" == "$REMOTE_COMMIT" ]]; then
        info "Already up to date! No updates available."
        echo
        read -r -p "Would you like to rebuild containers anyway? (y/N): " rebuild_choice
        if [[ ! "$rebuild_choice" =~ ^[Yy]$ ]]; then
            log "Update complete - no changes needed"
            exit 0
        fi
    else
        info "Updates available. Pulling changes..."
        
        # Stash any local changes to tracked files
        if [[ -n $(git status --porcelain) ]]; then
            git stash push -m "Auto-stash before update at $(date)"
            STASHED=true
        else
            STASHED=false
        fi
        
        # Pull updates
        if ! git pull origin "$(git branch --show-current)"; then
            err "Failed to pull updates"
            if [[ "$STASHED" == "true" ]]; then
                warn "Attempting to restore stashed changes..."
                git stash pop
            fi
            exit 1
        fi
        
        # Restore stashed changes if any
        if [[ "$STASHED" == "true" ]]; then
            info "Restoring local changes..."
            if ! git stash pop; then
                warn "Could not automatically restore local changes"
                warn "Your changes are saved in the stash"
                warn "Run 'git stash list' to see stashed changes"
            fi
        fi
        
        log "Successfully pulled updates"
        echo
    fi
}

show_changes() {
    log "Recent changes:"
    echo
    git log --oneline --decorate -5
    echo
}

rebuild_containers() {
    log "Rebuilding containers with updated images..."
    
    # Stop all stacks
    log "Stopping running containers..."
    for stack_dir in "$REPO_ROOT"/stacks/*/; do
        if [[ -f "${stack_dir}docker-compose.yml" ]]; then
            stack_name=$(basename "$stack_dir")
            info "Stopping $stack_name stack..."
            (cd "$stack_dir" && docker compose down) || warn "Could not stop $stack_name"
        fi
    done
    echo
    
    # Rebuild images that have Dockerfiles
    log "Rebuilding custom images..."
    
    if [[ -d "$REPO_ROOT/stacks/observability/signal-webhook-bridge" ]]; then
        info "Building signal-webhook-bridge..."
        (cd "$REPO_ROOT/stacks/observability" && docker compose build signal-webhook-bridge) || warn "Could not build signal-webhook-bridge"
    fi
    
    if [[ -d "$REPO_ROOT/stacks/ai-watchdog" ]]; then
        info "Building ai-watchdog..."
        (cd "$REPO_ROOT/stacks/ai-watchdog" && docker compose build) || warn "Could not build ai-watchdog"
    fi
    echo
    
    # Pull latest images for external services
    log "Pulling latest images for external services..."
    for stack_dir in "$REPO_ROOT"/stacks/*/; do
        if [[ -f "${stack_dir}docker-compose.yml" ]]; then
            stack_name=$(basename "$stack_dir")
            info "Pulling images for $stack_name..."
            (cd "$stack_dir" && docker compose pull) || warn "Could not pull images for $stack_name"
        fi
    done
    echo
}

restart_stacks() {
    log "Starting updated stacks..."
    
    # Create necessary networks if they don't exist
    if ! docker network inspect monitoring-network &> /dev/null; then
        info "Creating monitoring-network..."
        docker network create monitoring-network
    fi
    
    # Start each stack
    for stack_dir in "$REPO_ROOT"/stacks/*/; do
        if [[ -f "${stack_dir}docker-compose.yml" ]]; then
            stack_name=$(basename "$stack_dir")
            info "Starting $stack_name stack..."
            (cd "$stack_dir" && docker compose up -d) || warn "Could not start $stack_name"
        fi
    done
    echo
    
    log "All stacks restarted"
}

verify_deployment() {
    log "Verifying deployment..."
    echo
    
    sleep 5  # Give containers time to start
    
    info "Container status:"
    docker ps --format "table {{.Names}}\t{{.Status}}\t{{.State}}" | grep -E "pihole|unbound|keepalived|prometheus|grafana|alertmanager|signal|watchdog|loki|promtail" || true
    echo
    
    info "Checking for unhealthy containers..."
    UNHEALTHY=$(docker ps --filter "health=unhealthy" --format "{{.Names}}" | wc -l)
    
    if [[ $UNHEALTHY -gt 0 ]]; then
        warn "Found $UNHEALTHY unhealthy container(s):"
        docker ps --filter "health=unhealthy" --format "table {{.Names}}\t{{.Status}}"
    else
        log "All containers are healthy! ✓"
    fi
    echo
}

cleanup_old_images() {
    read -r -p "Would you like to remove old unused Docker images? (y/N): " cleanup_choice
    if [[ "$cleanup_choice" =~ ^[Yy]$ ]]; then
        log "Cleaning up old images..."
        docker image prune -f
        log "Cleanup complete"
    fi
    echo
}

show_summary() {
    log "Update Summary"
    echo
    cat << EOF
Update completed successfully!

Service URLs:
  Pi-hole:         http://$(grep PRIMARY_DNS_IP "$ENV_FILE" | cut -d'=' -f2)/admin
  Grafana:         http://$(grep HOST_IP "$ENV_FILE" | cut -d'=' -f2):3000
  Prometheus:      http://$(grep HOST_IP "$ENV_FILE" | cut -d'=' -f2):9090
  Alertmanager:    http://$(grep HOST_IP "$ENV_FILE" | cut -d'=' -f2):9093

Configuration backups saved in: $BACKUP_DIR

To view logs for a specific service:
  docker logs <container-name>

To view all container logs:
  docker compose -f stacks/<stack-name>/docker-compose.yml logs -f

EOF
}

main() {
    log "RPi HA DNS Stack - Update Script"
    echo
    
    # Check if running with appropriate permissions
    if [[ $EUID -ne 0 ]] && ! groups | grep -q docker; then
        warn "This script may require sudo or docker group membership."
        warn "If you encounter permission errors, run with sudo or add your user to docker group."
        echo
    fi
    
    check_prerequisites
    backup_config
    check_git_status
    pull_updates
    show_changes
    
    echo
    read -r -p "Would you like to rebuild and restart all containers with the updates? (Y/n): " restart_choice
    
    if [[ ! "$restart_choice" =~ ^[Nn]$ ]]; then
        rebuild_containers
        restart_stacks
        verify_deployment
        cleanup_old_images
        show_summary
    else
        info "Containers not restarted. Updates pulled but not applied."
        info "To apply updates later, run: bash scripts/update.sh"
    fi
    
    log "Update process complete! 🎉"
}

main "$@"
