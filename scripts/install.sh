#!/usr/bin/env bash
# Helper install script for rpi-ha-dns-stack
# - Installs Docker & docker compose plugin (if missing)
# - Ensures sysctl settings for IP forwarding
# - Creates required Docker networks (macvlan for DNS + observability network)
# - Creates required folders for volumes (pihole, unbound, observability, keepalived, ai-watchdog)
# - Copies .env.example -> .env if missing and prompts you to edit it
# - Brings up the stacks using docker compose files in /stacks
set -euo pipefail
IFS=$'\n\t'

# Ensure we get the repository root correctly
REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || (cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd))"
ENV_FILE="$REPO_ROOT/.env"
ENV_EXAMPLE="$REPO_ROOT/.env.example"
INSTALL_LOG="$REPO_ROOT/install.log"

DNS_NETWORK_NAME="dns_net"
OBS_NETWORK_NAME="observability_net"
PARENT_IFACE="eth0"
SUBNET="192.168.8.0/24"
GATEWAY="192.168.8.1"
HOST_IP="192.168.8.250"
VIP_ADDR="192.168.8.255"

# Track created networks for rollback
CREATED_NETWORKS=()

log() { echo -e "\n[install] $*" | tee -a "$INSTALL_LOG"; }
err() { echo -e "\n[install][ERROR] $*" | tee -a "$INSTALL_LOG" >&2; }
warn() { echo -e "\n[install][WARNING] $*" | tee -a "$INSTALL_LOG"; }

cleanup_on_error() {
  local exit_code=$?
  if [[ $exit_code -ne 0 ]]; then
    err "Installation failed with exit code $exit_code"
    log "Installation log saved to: $INSTALL_LOG"
    
    # Offer rollback
    if [[ -t 0 ]]; then
      read -r -p "Do you want to rollback changes? (y/N): " -n 1 response
      echo
      if [[ "$response" =~ ^[Yy]$ ]]; then
        rollback_changes
      fi
    fi
  fi
}

rollback_changes() {
  log "Rolling back changes..."
  
  # Stop containers if they were started
  if docker compose -f "$REPO_ROOT/stacks/dns/docker-compose.yml" ps -q 2>/dev/null | grep -q .; then
    log "Stopping DNS stack containers..."
    docker compose -f "$REPO_ROOT/stacks/dns/docker-compose.yml" down 2>/dev/null || true
  fi
  
  if docker compose -f "$REPO_ROOT/stacks/observability/docker-compose.yml" ps -q 2>/dev/null | grep -q .; then
    log "Stopping observability stack containers..."
    docker compose -f "$REPO_ROOT/stacks/observability/docker-compose.yml" down 2>/dev/null || true
  fi
  
  if docker compose -f "$REPO_ROOT/stacks/ai-watchdog/docker-compose.yml" ps -q 2>/dev/null | grep -q .; then
    log "Stopping ai-watchdog stack containers..."
    docker compose -f "$REPO_ROOT/stacks/ai-watchdog/docker-compose.yml" down 2>/dev/null || true
  fi
  
  # Remove created networks
  for network in "${CREATED_NETWORKS[@]}"; do
    if docker network inspect "$network" >/dev/null 2>&1; then
      log "Removing network: $network"
      docker network rm "$network" 2>/dev/null || true
    fi
  done
  
  log "Rollback complete. You can try running the installation again."
}

trap cleanup_on_error EXIT

load_env() {
  if [[ -f "$ENV_FILE" ]]; then
    log "Loading environment from $ENV_FILE"
    set -a
    source "$ENV_FILE" || true
    set +a
    DNS_NETWORK_NAME="${DNS_NETWORK_NAME:-dns_net}"
    OBS_NETWORK_NAME="${OBS_NETWORK_NAME:-observability_net}"
    PARENT_IFACE="${NETWORK_INTERFACE:-$PARENT_IFACE}"
    SUBNET="${SUBNET:-$SUBNET}"
    GATEWAY="${GATEWAY:-$GATEWAY}"
    HOST_IP="${HOST_IP:-$HOST_IP}"
    VIP_ADDR="${VIP_ADDRESS:-$VIP_ADDR}"
    
    # Validate passwords are not default values
    validate_passwords
  elif [[ -f "$ENV_EXAMPLE" ]]; then
    log "$ENV_FILE not found — copying .env.example -> .env"
    cp "$ENV_EXAMPLE" "$ENV_FILE"
    err "SECURITY: You must edit $ENV_FILE to set secure passwords before running the stack!"
    err "Required: PIHOLE_PASSWORD, GRAFANA_ADMIN_PASSWORD, VRRP_PASSWORD"
    err "Generate secure passwords with: openssl rand -base64 32"
    exit 1
  else
    err "No .env or .env.example found in repo root ($REPO_ROOT). Create one before continuing."
    exit 1
  fi
}

validate_passwords() {
  local has_weak_passwords=false
  
  # Check for default/weak passwords
  if [[ "${PIHOLE_PASSWORD:-}" == "CHANGE_ME_REQUIRED" ]] || [[ "${PIHOLE_PASSWORD:-}" == "ChangeThisSecurePassword123!" ]] || [[ -z "${PIHOLE_PASSWORD:-}" ]]; then
    err "SECURITY: PIHOLE_PASSWORD is not set or uses default value in $ENV_FILE"
    has_weak_passwords=true
  fi
  
  if [[ "${GRAFANA_ADMIN_PASSWORD:-}" == "CHANGE_ME_REQUIRED" ]] || [[ "${GRAFANA_ADMIN_PASSWORD:-}" == "ChangeThisGrafanaPassword!" ]] || [[ -z "${GRAFANA_ADMIN_PASSWORD:-}" ]]; then
    err "SECURITY: GRAFANA_ADMIN_PASSWORD is not set or uses default value in $ENV_FILE"
    has_weak_passwords=true
  fi
  
  if [[ "${VRRP_PASSWORD:-}" == "CHANGE_ME_REQUIRED" ]] || [[ "${VRRP_PASSWORD:-}" == "SecureVRRPPassword123!" ]] || [[ -z "${VRRP_PASSWORD:-}" ]]; then
    err "SECURITY: VRRP_PASSWORD is not set or uses default value in $ENV_FILE"
    has_weak_passwords=true
  fi
  
  if [[ "$has_weak_passwords" == true ]]; then
    err ""
    err "Please set secure passwords in $ENV_FILE before running the installation."
    err "Generate secure passwords with: openssl rand -base64 32"
    err ""
    exit 1
  fi
  
  log "Password validation passed"
}

check_prerequisites() {
  log "Checking system prerequisites..."
  
  # Check OS
  if [[ "$(uname -s)" != "Linux" ]]; then
    err "This script requires Linux"
    exit 1
  fi
  
  # Check architecture
  ARCH=$(uname -m)
  case "$ARCH" in
    aarch64|armv7l|x86_64)
      log "Supported architecture: $ARCH"
      ;;
    *)
      err "Unsupported architecture: $ARCH (requires ARM or x86_64)"
      exit 1
      ;;
  esac
  
  # Check disk space (minimum 5GB)
  AVAILABLE_GB=$(df -BG / | awk 'NR==2 {print $4}' | sed 's/G//')
  if [[ "$AVAILABLE_GB" -lt 5 ]]; then
    err "Insufficient disk space: ${AVAILABLE_GB}GB (minimum 5GB required)"
    exit 1
  fi
  log "Available disk space: ${AVAILABLE_GB}GB"
  
  # Check memory (minimum 1GB)
  TOTAL_MEM_KB=$(grep MemTotal /proc/meminfo | awk '{print $2}')
  TOTAL_MEM_MB=$((TOTAL_MEM_KB / 1024))
  if [[ "$TOTAL_MEM_MB" -lt 1024 ]]; then
    err "Insufficient memory: ${TOTAL_MEM_MB}MB (minimum 1024MB required)"
    exit 1
  fi
  log "Total memory: ${TOTAL_MEM_MB}MB"
  
  # Check network connectivity
  if ! ping -c 1 -W 3 8.8.8.8 >/dev/null 2>&1; then
    err "No internet connectivity detected (required for installation)"
    exit 1
  fi
  log "Network connectivity verified"
}

install_docker() {
  if command -v docker >/dev/null 2>&1; then
    log "Docker is already installed."
  else
    warn "SECURITY: About to download and execute Docker installation script from https://get.docker.com"
    warn "This script will be run with elevated privileges."
    
    if [[ -t 0 ]]; then
      read -r -p "Do you want to proceed with Docker installation? (y/N): " -n 1 response
      echo
      if [[ ! "$response" =~ ^[Yy]$ ]]; then
        err "Docker installation cancelled by user"
        err "Please install Docker manually and re-run this script"
        exit 1
      fi
    fi
    
    log "Docker not found — installing Docker Engine using official convenience script..."
    curl -fsSL https://get.docker.com | sh
    log "Docker installed."
  fi

  # Verify Docker daemon is running
  if ! docker version >/dev/null 2>&1; then
    warn "Docker installed but not running. Attempting to start Docker service..."
    if command -v systemctl >/dev/null 2>&1; then
      sudo systemctl start docker || true
      sleep 3
    fi
    
    # Check again after attempting to start
    if ! docker version >/dev/null 2>&1; then
      err "Docker installed but not running or accessible."
      err "Please start docker service with: sudo systemctl start docker"
      err "And ensure your user is in the docker group: sudo usermod -aG docker $USER"
      exit 1
    fi
  fi
  log "Docker daemon is running and accessible."
  
  # Verify user has Docker permissions
  if ! docker ps >/dev/null 2>&1; then
    warn "Docker is running but current user does not have permissions."
    if [[ $EUID -ne 0 ]]; then
      if getent group docker >/dev/null 2>&1; then
        sudo usermod -aG docker "$USER" || true
        log "Added user $USER to docker group."
        warn "You may need to log out and back in for Docker permissions to take effect."
        warn "Or run: newgrp docker"
      fi
    fi
  else
    log "Docker permissions verified."
  fi

  if docker compose version >/dev/null 2>&1; then
    log "Docker Compose plugin is available."
  else
    log "Installing Docker Compose plugin..."
    if command -v apt-get >/dev/null 2>&1; then
      sudo apt-get update -qq
      sudo apt-get install -y docker-compose-plugin || true
    fi
    if ! docker compose version >/dev/null 2>&1; then
      err "docker compose plugin could not be installed automatically. Please install docker compose plugin (or docker-compose) and re-run."
      exit 1
    fi
    log "Docker Compose plugin installed."
  fi
}

enable_ip_forward() {
  log "Enabling net.ipv4.ip_forward=1"
  if ! grep -q '^net.ipv4.ip_forward=1' /etc/sysctl.conf 2>/dev/null; then
    echo "net.ipv4.ip_forward=1" | sudo tee -a /etc/sysctl.conf >/dev/null
  fi
  sudo sysctl -p >/dev/null || true
}

interactive_configuration() {
  log "=== Interactive Configuration ==="
  echo
  
  # Check if .env already exists and has been configured
  if [[ -f "$ENV_FILE" ]]; then
    if ! grep -q "CHANGE_ME_REQUIRED" "$ENV_FILE" 2>/dev/null && \
       ! grep -q "ChangeThisSecurePassword" "$ENV_FILE" 2>/dev/null; then
      log ".env file already exists and appears to be configured."
      read -r -p "Do you want to reconfigure it? (y/N): " -n 1 response
      echo
      if [[ ! "$response" =~ ^[Yy]$ ]]; then
        log "Using existing .env configuration"
        return 0
      fi
    fi
  fi
  
  # Detect current Pi IP
  DETECTED_IP=$(hostname -I | awk '{print $1}' || echo "192.168.1.100")
  DETECTED_IFACE=$(ip route show default | grep -oP 'dev \K\S+' | head -1 || echo "eth0")
  
  echo
  log "Detected Pi IP: $DETECTED_IP"
  log "Detected Interface: $DETECTED_IFACE"
  echo
  
  # Ask for deployment mode
  echo "Choose deployment mode:"
  echo "  1) Single-Node  - One Raspberry Pi (simpler, no hardware failover)"
  echo "  2) HA (High Availability) - Two Raspberry Pis with automatic failover"
  echo
  read -r -p "Enter choice (1 or 2) [1]: " MODE_CHOICE
  MODE_CHOICE=${MODE_CHOICE:-1}
  
  # Ask for Pi's LAN IP
  echo
  read -r -p "Enter this Pi's LAN IP address [$DETECTED_IP]: " PI_IP
  PI_IP=${PI_IP:-$DETECTED_IP}
  
  # Ask for network interface
  echo
  read -r -p "Enter network interface name [$DETECTED_IFACE]: " IFACE
  IFACE=${IFACE:-$DETECTED_IFACE}
  
  # Configure based on mode
  if [[ "$MODE_CHOICE" == "1" ]]; then
    # Single-node mode
    log "Configuring for Single-Node mode"
    VIP=$PI_IP
    ROLE="MASTER"
    
    log "In single-node mode, DNS VIP = Pi IP ($VIP)"
  else
    # HA mode
    log "Configuring for HA (High Availability) mode"
    echo
    read -r -p "Enter Virtual IP (VIP) address (must be unused on your network): " VIP
    
    if [[ -z "$VIP" ]]; then
      err "VIP is required for HA mode"
      exit 1
    fi
    
    echo
    echo "Node role:"
    echo "  MASTER  - Primary node (higher priority, runs VIP by default)"
    echo "  BACKUP  - Secondary node (takes over if primary fails)"
    echo
    read -r -p "Enter node role (MASTER or BACKUP) [MASTER]: " ROLE
    ROLE=${ROLE:-MASTER}
    ROLE=$(echo "$ROLE" | tr '[:lower:]' '[:upper:]')
    
    if [[ "$ROLE" != "MASTER" && "$ROLE" != "BACKUP" ]]; then
      err "Invalid role. Must be MASTER or BACKUP"
      exit 1
    fi
  fi
  
  # Ask for Pi-hole password
  echo
  log "Set Pi-hole admin password (minimum 8 characters)"
  while true; do
    read -r -s -p "Pi-hole password: " PIHOLE_PASS
    echo
    if [[ ${#PIHOLE_PASS} -lt 8 ]]; then
      err "Password must be at least 8 characters"
      continue
    fi
    read -r -s -p "Confirm password: " PIHOLE_PASS_CONFIRM
    echo
    if [[ "$PIHOLE_PASS" != "$PIHOLE_PASS_CONFIRM" ]]; then
      err "Passwords do not match"
      continue
    fi
    break
  done
  
  # Generate other passwords
  log "Generating secure passwords for Grafana and VRRP..."
  GRAFANA_PASS=$(openssl rand -base64 24)
  VRRP_PASS=$(openssl rand -base64 16)
  
  # Calculate subnet and gateway from Pi IP
  SUBNET=$(echo "$PI_IP" | awk -F. '{print $1"."$2"."$3".0/24"}')
  GATEWAY=$(echo "$PI_IP" | awk -F. '{print $1"."$2"."$3".1"}')
  
  # Create or update .env file
  log "Creating .env configuration..."
  
  # Start with example if it exists, otherwise create from scratch
  if [[ -f "$ENV_EXAMPLE" ]]; then
    cp "$ENV_EXAMPLE" "$ENV_FILE"
  else
    touch "$ENV_FILE"
  fi
  
  # Update configuration values
  update_env_value "HOST_IP" "$PI_IP"
  update_env_value "DNS_VIP" "$VIP"
  update_env_value "VIP_ADDRESS" "$VIP"
  update_env_value "NODE_ROLE" "$ROLE"
  update_env_value "NETWORK_INTERFACE" "$IFACE"
  update_env_value "SUBNET" "$SUBNET"
  update_env_value "GATEWAY" "$GATEWAY"
  update_env_value "PIHOLE_PASSWORD" "$PIHOLE_PASS"
  update_env_value "GRAFANA_ADMIN_PASSWORD" "$GRAFANA_PASS"
  update_env_value "VRRP_PASSWORD" "$VRRP_PASS"
  
  # Set priority based on role
  if [[ "$ROLE" == "MASTER" ]]; then
    update_env_value "VRRP_PRIORITY" "100"
  else
    update_env_value "VRRP_PRIORITY" "90"
  fi
  
  echo
  log "Configuration Summary:"
  log "  Mode: $([ "$MODE_CHOICE" == "1" ] && echo "Single-Node" || echo "HA")"
  log "  Pi IP: $PI_IP"
  log "  DNS VIP: $VIP"
  log "  Node Role: $ROLE"
  log "  Interface: $IFACE"
  log "  Subnet: $SUBNET"
  log "  Gateway: $GATEWAY"
  echo
  log "✓ Configuration saved to $ENV_FILE"
  
  if [[ "$MODE_CHOICE" == "2" ]]; then
    echo
    log "IMPORTANT: For HA mode, you need to set up a second Pi with:"
    log "  - Same VIP: $VIP"
    log "  - Different Pi IP (not $PI_IP)"
    log "  - Opposite role ($([ "$ROLE" == "MASTER" ] && echo "BACKUP" || echo "MASTER"))"
    log "  - Same VRRP password"
  fi
}

update_env_value() {
  local key="$1"
  local value="$2"
  local file="${3:-$ENV_FILE}"
  
  # Escape special characters in value
  local safe_value=$(echo "$value" | sed 's/[\/&]/\\&/g')
  
  # Check if key exists
  if grep -q "^${key}=" "$file" 2>/dev/null; then
    # Replace existing value
    sed -i "s/^${key}=.*$/${key}=\"${safe_value}\"/" "$file"
  else
    # Add new key-value pair
    echo "${key}=\"${safe_value}\"" >> "$file"
  fi
}

create_env_symlinks() {
  log "Creating .env symlinks in stack directories"
  # Docker compose looks for .env in the same directory as docker-compose.yml
  # We keep the master .env in repo root and symlink to it from each stack
  for stack_dir in "$REPO_ROOT/stacks/dns" "$REPO_ROOT/stacks/observability" "$REPO_ROOT/stacks/ai-watchdog"; do
    if [[ ! -e "$stack_dir/.env" ]]; then
      ln -sf "../../.env" "$stack_dir/.env"
      log "Created .env symlink in $(basename "$stack_dir")"
    else
      log ".env already exists in $(basename "$stack_dir")"
    fi
  done
}

create_directories() {
  log "Creating volume directories (pihole, unbound, keepalived, observability, ai-watchdog)"
  mkdir -p "$REPO_ROOT"/{stacks/dns/pihole1/etc-pihole,stacks/dns/pihole1/etc-dnsmasq.d,stacks/dns/pihole2/etc-pihole,stacks/dns/pihole2/etc-dnsmasq.d,stacks/dns/unbound,stacks/dns/keepalived,stacks/observability/prometheus,stacks/observability/grafana,stacks/observability/alertmanager,stacks/observability/signal-cli-config,stacks/ai-watchdog}
  
  # Copy shared unbound config if not exists
  if [[ ! -f "$REPO_ROOT/stacks/dns/unbound/unbound.conf" ]] && [[ -f "$REPO_ROOT/stacks/dns/unbound1/unbound.conf" ]]; then
    log "Migrating to shared unbound configuration..."
    cp "$REPO_ROOT/stacks/dns/unbound1/unbound.conf" "$REPO_ROOT/stacks/dns/unbound/unbound.conf"
  fi
  
  log "Directories created."
}
docker_network_exists() { docker network inspect "$1" >/dev/null 2>&1; }

create_macvlan_network() {
  local name="${1:-$DNS_NETWORK_NAME}"
  local parent="${2:-$PARENT_IFACE}"
  local subnet_cidr="${3:-$SUBNET}"
  local gw="${4:-$GATEWAY}"

  if docker_network_exists "$name"; then
    log "Docker network '$name' already exists — skipping creation."
    return 0
  fi

  log "Creating macvlan network '$name' on parent '$parent' with subnet $subnet_cidr and gateway $gw"
  if ! ip link show "$parent" >/dev/null 2>&1; then
    err "Parent interface '$parent' does not exist on this host. Creating a bridge fallback network named '$name-bridge' instead."
    docker network create --driver bridge "$name-bridge"
    CREATED_NETWORKS+=("$name-bridge")
    log "Created bridge network '$name-bridge'. Update stacks/dns/docker-compose.yml to use it if you cannot use macvlan."
    return 0
  fi

  docker network create -d macvlan \
    --subnet="$subnet_cidr" \
    --gateway="$gw" \
    -o parent="$parent" \
    "$name" \
    || { err "Failed to create macvlan network. You may need to tweak parent interface or run as root."; exit 1; }
  CREATED_NETWORKS+=("$name")
  log "macvlan network '$name' created."
}

create_observability_network() {
  local name="${1:-$OBS_NETWORK_NAME}"
  if docker_network_exists "$name"; then
    log "Observability network '$name' already exists — skipping."
    return 0
  fi
  log "Creating observability network '$name' (bridge)"
  docker network create "$name"
  CREATED_NETWORKS+=("$name")
  log "Observability network created."
}

deploy_stacks() {
  log "Bringing up DNS stack"
  docker compose -f "$REPO_ROOT/stacks/dns/docker-compose.yml" up -d

  log "Bringing up observability stack"
  docker compose -f "$REPO_ROOT/stacks/observability/docker-compose.yml" up -d

  log "Bringing up ai-watchdog stack"
  docker compose -f "$REPO_ROOT/stacks/ai-watchdog/docker-compose.yml" up -d

  log "All stacks started (docker compose reported no fatal errors)."
}

basic_verification() {
  log "Basic verification of running containers"
  docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
  log "Checking if keepalived VIP is present on host (may be created by container in host mode)"
  ip addr show dev "${PARENT_IFACE}" | grep -E "${VIP_ADDR}" || echo "VIP ${VIP_ADDR} not found on ${PARENT_IFACE} (this may be normal before keepalived runs)."
}

main() {
  log "Running rpi-ha-dns-stack installer helper from $REPO_ROOT"
  check_prerequisites
  
  # Offer interactive configuration
  if [[ -t 0 ]]; then
    # Interactive terminal detected
    echo
    log "Would you like to use interactive configuration or manually edit .env?"
    echo "  1) Interactive configuration (recommended for most users)"
    echo "  2) Manual .env editing (for advanced users)"
    echo
    read -r -p "Enter choice (1 or 2) [1]: " CONFIG_CHOICE
    CONFIG_CHOICE=${CONFIG_CHOICE:-1}
    
    if [[ "$CONFIG_CHOICE" == "1" ]]; then
      interactive_configuration
    else
      log "Skipping interactive configuration. You'll need to edit .env manually."
      load_env
    fi
  else
    # Non-interactive (e.g., piped script)
    log "Non-interactive mode detected. Loading existing .env or using defaults."
    load_env
  fi
  
  install_docker
  enable_ip_forward
  create_directories
  create_env_symlinks

  # Load/reload environment after configuration
  load_env

  create_macvlan_network "${DNS_NETWORK_NAME}" "${PARENT_IFACE}" "${SUBNET}" "${GATEWAY}"
  create_observability_network "${OBS_NETWORK_NAME}"

  deploy_stacks
  basic_verification

  log "Installer script finished. If you changed group membership for your user, log out and back in (or reboot) to activate docker group permissions."
  echo
  log "Next steps:"
  cat <<EOF
  - Set your router's DNS to: ${VIP_ADDR}
  - Visit Pi-hole UI: http://${VIP_ADDR}/admin
  - Visit Grafana: http://${HOST_IP}:3000
  - Visit Web Wizard: http://${HOST_IP}:8080 (to apply DNS profiles)
  - Troubleshoot with: docker logs <container-name>
  
  For detailed documentation, see:
  - docs/install-single-pi.md (single-node setup)
  - docs/install-two-pi-ha.md (HA setup)
  - docs/first-run-wizard.md (web wizard guide)
EOF
}

main "$@"