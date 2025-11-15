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

REPO_ROOT="$(cd "");/.." && pwd)"
ENV_FILE="$REPO_ROOT/.env"
ENV_EXAMPLE="$REPO_ROOT/.env.example"

DNS_NETWORK_NAME="dns_net"
OBS_NETWORK_NAME="observability_net"
PARENT_IFACE="eth0"
SUBNET="192.168.8.0/24"
GATEWAY="192.168.8.1"
HOST_IP="192.168.8.240"
VIP_ADDR="192.168.8.245"

log() { echo -e "\n[install] $*"; }
err() { echo -e "\n[install][ERROR] $*" >&2; }

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
  elif [[ -f "$ENV_EXAMPLE" ]]; then
    log "$ENV_FILE not found — copying .env.example -> .env"
    cp "$ENV_EXAMPLE" "$ENV_FILE"
    log "Please edit $ENV_FILE to set secrets (PIHOLE_PASSWORD, VRRP_PASSWORD, etc.) before running the stack. Continuing with defaults from .env.example."
    source "$ENV_FILE" || true
  else
    err "No .env or .env.example found in repo root ($REPO_ROOT). Create one before continuing."
    exit 1
  fi
}

install_docker() {
  if command -v docker >/dev/null 2>&1; then
    log "Docker is already installed."
  else
    log "Docker not found — installing Docker Engine using official convenience script..."
    curl -fsSL https://get.docker.com | sh
    log "Docker installed."
  fi

  if docker version >/dev/null 2>&1; then
    log "Docker is operational."
  else
    err "Docker installed but not running or accessible. Please start docker service and re-run this script as a user in the docker group or as root."
    exit 1
  fi

  if docker compose version >/dev/null 2>&1; then
    log "Docker Compose plugin is available."
  else
    log "Installing Docker Compose plugin..."
    if command -v apt-get >/dev/null 2>&1; then
      apt-get update
      apt-get install -y docker-compose-plugin || true
    fi
    if ! docker compose version >/dev/null 2>&1; then
      err "docker compose plugin could not be installed automatically. Please install docker compose plugin (or docker-compose) and re-run."
      exit 1
    fi
    log "Docker Compose plugin installed."
  fi

  if [[ $EUID -ne 0 ]]; then
    if getent group docker >/dev/null 2>&1; then
      sudo usermod -aG docker "$SUDO_USER" || true
      log "Added user $SUDO_USER to docker group (you may need to re-login)."
    fi
  fi
}

enable_ip_forward() {
  log "Enabling net.ipv4.ip_forward=1"
  if ! grep -q '^net.ipv4.ip_forward=1' /etc/sysctl.conf 2>/dev/null; then
    echo "net.ipv4.ip_forward=1" | sudo tee -a /etc/sysctl.conf >/dev/null
  fi
  sudo sysctl -p >/dev/null || true
}

create_directories() {
  log "Creating volume directories (pihole, unbound, keepalived, observability, ai-watchdog)"
  mkdir -p "$REPO_ROOT"/{stacks/dns/pihole1/etc-pihole,stacks/dns/pihole1/etc-dnsmasq.d,stacks/dns/pihole2/etc-pihole,stacks/dns/pihole2/etc-dnsmasq.d,stacks/dns/unbound1,stacks/dns/unbound2,stacks/dns/keepalived,stacks/observability/prometheus,stacks/observability/grafana,stacks/observability/alertmanager,stacks/ai-watchdog}
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
    log "Created bridge network '$name-bridge'. Update stacks/dns/docker-compose.yml to use it if you cannot use macvlan."
    return 0
  fi

  docker network create -d macvlan \
    --subnet="$subnet_cidr" \
    --gateway="$gw" \
    -o parent="$parent" \
    "$name" \
    || { err "Failed to create macvlan network. You may need to tweak parent interface or run as root."; exit 1; }
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
  load_env
  install_docker
  enable_ip_forward
  create_directories

  create_macvlan_network "${DNS_NETWORK_NAME}" "${PARENT_IFACE}" "${SUBNET}" "${GATEWAY}"
  create_observability_network "${OBS_NETWORK_NAME}"

  if grep -q "ChangeThisSecurePassword" "$ENV_FILE" 2>/dev/null || grep -q "ChangeThisGrafanaPassword" "$ENV_FILE" 2>/dev/null; then
    log "Warning: .env contains default placeholder passwords. Edit $ENV_FILE to set secure passwords, then re-run or press ENTER to continue."
    read -r -p "Press ENTER to continue or Ctrl-C to abort..."
  fi

  deploy_stacks
  basic_verification

  log "Installer script finished. If you changed group membership for your user, log out and back in (or reboot) to activate docker group permissions."
  echo
  log "Next steps (run these on your Pi):"
  cat <<'EOF'
  - Visit Pi-hole UI: http://<primary-ip-or-vip>/admin
  - Visit Grafana: http://<host-ip>:3000 (admin credentials from .env)
  - Check Prometheus targets: http://<host-ip>:9090/targets
  - Troubleshoot with: docker logs <container-name>
EOF
}

main "$@"