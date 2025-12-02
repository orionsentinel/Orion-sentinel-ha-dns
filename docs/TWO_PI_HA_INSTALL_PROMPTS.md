# Install.sh Two-Pi HA Enhancement - Pseudocode & CLI Prompts

## Overview
This document describes how to extend `install.sh` or create a new installation flow that explicitly handles Two-Pi HA as a first-class deployment option.

## Proposed CLI Prompts Flow

### Current install.sh Flow
```
1. Check OS
2. Install Dependencies (Docker, Git)
3. Clone Repository
4. Launch Web UI
```

### Enhanced install.sh with Two-Pi HA Path

```bash
#!/usr/bin/env bash
# Enhanced install.sh with Two-Pi HA support

# ... existing banner and checks ...

section "Deployment Mode Selection"

echo "How do you want to deploy Orion Sentinel DNS HA?"
echo ""
echo "1) Single-Node HA (One Raspberry Pi)"
echo "   - Container-level redundancy"
echo "   - Best for most home users"
echo "   - Requires: 1 Raspberry Pi"
echo ""
echo "2) Two-Pi HA (Two Raspberry Pis)"
echo "   - Hardware-level redundancy"
echo "   - Automatic failover between physical nodes"
echo "   - Requires: 2 Raspberry Pis with static IPs"
echo ""
read -p "Enter your choice (1 or 2): " DEPLOYMENT_CHOICE

case $DEPLOYMENT_CHOICE in
    1)
        DEPLOYMENT_MODE="single-pi-ha"
        log "Selected: Single-Node HA"
        configure_single_node
        ;;
    2)
        DEPLOYMENT_MODE="two-pi-ha"
        log "Selected: Two-Pi HA"
        configure_two_pi_ha
        ;;
    *)
        err "Invalid choice. Please run the installer again."
        exit 1
        ;;
esac
```

## Two-Pi HA Configuration Function

```bash
configure_two_pi_ha() {
    section "Two-Pi HA Configuration"
    
    info "You'll need to run this installer on BOTH Raspberry Pis."
    info "First, let's configure THIS node..."
    echo ""
    
    # Step 1: Node Role
    echo "What is the role of THIS Raspberry Pi?"
    echo "1) Primary (Pi1) - Preferred MASTER, higher priority"
    echo "2) Secondary (Pi2) - BACKUP, takes over if Primary fails"
    read -p "Enter choice (1 or 2): " NODE_CHOICE
    
    case $NODE_CHOICE in
        1)
            NODE_ROLE="primary"
            KEEPALIVED_PRIORITY=200
            NODE_HOSTNAME="pi1-dns"
            log "This node will be: Primary (Pi1)"
            ;;
        2)
            NODE_ROLE="secondary"
            KEEPALIVED_PRIORITY=150
            NODE_HOSTNAME="pi2-dns"
            log "This node will be: Secondary (Pi2)"
            ;;
        *)
            err "Invalid choice"
            exit 1
            ;;
    esac
    
    # Step 2: This Node's IP
    DEFAULT_IP=$(hostname -I | awk '{print $1}')
    read -p "Enter THIS node's IP address [$DEFAULT_IP]: " HOST_IP
    HOST_IP=${HOST_IP:-$DEFAULT_IP}
    log "This node IP: $HOST_IP"
    
    # Step 3: Peer Node IP
    read -p "Enter the PEER node's IP address: " PEER_IP
    if [[ -z "$PEER_IP" ]]; then
        err "Peer IP is required for Two-Pi HA"
        exit 1
    fi
    log "Peer node IP: $PEER_IP"
    
    # Step 4: VIP Address
    SUGGESTED_VIP=$(echo $HOST_IP | sed 's/\.[0-9]*$/\.249/')
    read -p "Enter the Virtual IP (VIP) address [$SUGGESTED_VIP]: " VIP_ADDRESS
    VIP_ADDRESS=${VIP_ADDRESS:-$SUGGESTED_VIP}
    
    warn "IMPORTANT: VIP must NOT be in your DHCP range!"
    warn "IMPORTANT: Use the SAME VIP on both Pi1 and Pi2!"
    log "VIP: $VIP_ADDRESS"
    
    # Step 5: Network Interface
    DEFAULT_IFACE="eth0"
    read -p "Enter network interface [$DEFAULT_IFACE]: " NETWORK_INTERFACE
    NETWORK_INTERFACE=${NETWORK_INTERFACE:-$DEFAULT_IFACE}
    log "Interface: $NETWORK_INTERFACE"
    
    # Step 6: VRRP Password
    echo ""
    warn "VRRP Password is used for authentication between nodes"
    warn "CRITICAL: Must be the SAME on both Pi1 and Pi2!"
    read -sp "Enter VRRP password (min 8 chars): " VRRP_PASSWORD
    echo ""
    
    if [[ ${#VRRP_PASSWORD} -lt 8 ]]; then
        err "VRRP password must be at least 8 characters"
        exit 1
    fi
    
    # Step 7: Pi-hole Password
    echo ""
    warn "Pi-hole Password for admin UI access"
    warn "CRITICAL: Must be the SAME on both Pi1 and Pi2!"
    read -sp "Enter Pi-hole admin password (min 8 chars): " PIHOLE_PASSWORD
    echo ""
    
    if [[ ${#PIHOLE_PASSWORD} -lt 8 ]]; then
        err "Pi-hole password must be at least 8 characters"
        exit 1
    fi
    
    # Step 8: Summary
    section "Configuration Summary"
    echo "Deployment Mode:      Two-Pi HA"
    echo "This Node:"
    echo "  - Role:             $NODE_ROLE"
    echo "  - IP:               $HOST_IP"
    echo "  - Hostname:         $NODE_HOSTNAME"
    echo "  - Keepalived Priority: $KEEPALIVED_PRIORITY"
    echo ""
    echo "Peer Node IP:         $PEER_IP"
    echo "Virtual IP (VIP):     $VIP_ADDRESS"
    echo "Network Interface:    $NETWORK_INTERFACE"
    echo ""
    
    read -p "Is this configuration correct? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        err "Configuration cancelled. Please run installer again."
        exit 1
    fi
    
    # Step 9: Write to .env
    write_two_pi_env
    
    # Step 10: Deploy
    deploy_two_pi_ha
}
```

## Write Configuration to .env

```bash
write_two_pi_env() {
    section "Writing Configuration"
    
    ENV_FILE="$INSTALL_DIR/.env"
    
    # Copy from .env.multinode.example if available, otherwise .env.example
    if [[ -f "$INSTALL_DIR/.env.multinode.example" ]]; then
        cp "$INSTALL_DIR/.env.multinode.example" "$ENV_FILE"
        log "Copied .env.multinode.example to .env"
    else
        cp "$INSTALL_DIR/.env.example" "$ENV_FILE"
        log "Copied .env.example to .env"
    fi
    
    # Update values using sed or similar
    sed -i "s/^NODE_ROLE=.*/NODE_ROLE=$NODE_ROLE/" "$ENV_FILE"
    sed -i "s/^HOST_IP=.*/HOST_IP=$HOST_IP/" "$ENV_FILE"
    sed -i "s/^NODE_HOSTNAME=.*/NODE_HOSTNAME=$NODE_HOSTNAME/" "$ENV_FILE"
    sed -i "s/^PEER_IP=.*/PEER_IP=$PEER_IP/" "$ENV_FILE"
    sed -i "s/^VIP_ADDRESS=.*/VIP_ADDRESS=$VIP_ADDRESS/" "$ENV_FILE"
    sed -i "s/^NETWORK_INTERFACE=.*/NETWORK_INTERFACE=$NETWORK_INTERFACE/" "$ENV_FILE"
    sed -i "s/^KEEPALIVED_PRIORITY=.*/KEEPALIVED_PRIORITY=$KEEPALIVED_PRIORITY/" "$ENV_FILE"
    sed -i "s/^VRRP_PASSWORD=.*/VRRP_PASSWORD=$VRRP_PASSWORD/" "$ENV_FILE"
    sed -i "s/^PIHOLE_PASSWORD=.*/PIHOLE_PASSWORD=$PIHOLE_PASSWORD/" "$ENV_FILE"
    sed -i "s/^DEPLOYMENT_MODE=.*/DEPLOYMENT_MODE=two-pi-ha/" "$ENV_FILE"
    
    # Set monitoring based on role
    if [[ "$NODE_ROLE" == "primary" ]]; then
        sed -i "s/^DEPLOY_MONITORING=.*/DEPLOY_MONITORING=true/" "$ENV_FILE"
    else
        sed -i "s/^DEPLOY_MONITORING=.*/DEPLOY_MONITORING=false/" "$ENV_FILE"
    fi
    
    log "Configuration written to $ENV_FILE"
}
```

## Deploy Two-Pi HA

```bash
deploy_two_pi_ha() {
    section "Deploying Two-Pi HA Services"
    
    cd "$INSTALL_DIR/stacks/dns" || exit
    
    # Determine profile based on node role
    if [[ "$NODE_ROLE" == "primary" ]]; then
        PROFILE="two-pi-ha-pi1"
        log "Deploying Primary (Pi1) services..."
    else
        PROFILE="two-pi-ha-pi2"
        log "Deploying Secondary (Pi2) services..."
    fi
    
    # Deploy using docker compose
    if docker compose --profile "$PROFILE" up -d; then
        log "Services deployed successfully"
    else
        err "Failed to deploy services"
        exit 1
    fi
    
    # Wait for services to start
    sleep 10
    
    # Run health check
    section "Health Check"
    if bash "$INSTALL_DIR/scripts/orion-dns-ha-health.sh"; then
        log "Health check passed!"
    else
        warn "Health check reported issues. Review output above."
    fi
    
    # Show next steps
    show_two_pi_next_steps
}
```

## Show Next Steps

```bash
show_two_pi_next_steps() {
    echo ""
    echo -e "${GREEN}${BOLD}═══════════════════════════════════════════════════════════${NC}"
    echo -e "${GREEN}${BOLD}   Two-Pi HA Deployment Complete on $NODE_ROLE node!${NC}"
    echo -e "${GREEN}${BOLD}═══════════════════════════════════════════════════════════${NC}"
    echo ""
    
    if [[ "$NODE_ROLE" == "primary" ]]; then
        echo -e "${CYAN}✓ Primary node (Pi1) is deployed${NC}"
        echo ""
        echo -e "${YELLOW}NEXT STEPS:${NC}"
        echo "1. Run this installer on the SECONDARY node (Pi2)"
        echo "   - Choose 'Two-Pi HA' mode"
        echo "   - Select 'Secondary (Pi2)' role"
        echo "   - Use the SAME VIP: $VIP_ADDRESS"
        echo "   - Use the SAME passwords!"
        echo ""
        echo "2. After both nodes are deployed:"
        echo "   - Check VIP ownership: ip addr show eth0 | grep $VIP_ADDRESS"
        echo "   - Test DNS: dig google.com @$VIP_ADDRESS"
        echo "   - Run health check: bash scripts/orion-dns-ha-health.sh"
        echo ""
    else
        echo -e "${CYAN}✓ Secondary node (Pi2) is deployed${NC}"
        echo ""
        echo -e "${YELLOW}VERIFICATION:${NC}"
        echo "1. Check VIP ownership (should be on Primary):"
        echo "   - On Primary: ip addr show eth0 | grep $VIP_ADDRESS"
        echo "   - On Secondary: ip addr show eth0 | grep $VIP_ADDRESS"
        echo "     (Secondary should NOT show VIP)"
        echo ""
        echo "2. Test DNS resolution:"
        echo "   dig google.com @$VIP_ADDRESS"
        echo ""
        echo "3. Test failover:"
        echo "   - On Primary: docker stop keepalived"
        echo "   - Wait 10 seconds"
        echo "   - VIP should move to Secondary"
        echo "   - DNS should still work"
        echo ""
    fi
    
    echo -e "${CYAN}Documentation:${NC}"
    echo "  - Quick Start: cat MULTI_NODE_QUICKSTART.md"
    echo "  - Health Check: bash scripts/orion-dns-ha-health.sh"
    echo "  - Pi-hole Admin: http://$VIP_ADDRESS/admin"
    echo ""
    echo -e "${GREEN}${BOLD}═══════════════════════════════════════════════════════════${NC}"
}
```

## Integration Points

### Option 1: Extend Existing install.sh
Add the Two-Pi HA flow before launching the web UI:
```bash
# In main():
check_os
install_dependencies
clone_repository

# NEW: Offer CLI configuration before web UI
echo "Configure now via:"
echo "1) Command Line (quick, automated)"
echo "2) Web UI (interactive, visual)"
read -p "Choice (1 or 2): " CONFIG_METHOD

if [[ "$CONFIG_METHOD" == "1" ]]; then
    configure_via_cli  # Calls configure_two_pi_ha or configure_single_node
else
    launch_web_ui
fi
```

### Option 2: Create Dedicated scripts/install-two-pi-ha.sh
```bash
#!/usr/bin/env bash
# Dedicated Two-Pi HA installer
# Usage: bash scripts/install-two-pi-ha.sh

# Contains only Two-Pi HA flow
# Simpler, more focused
# Can be called from main install.sh or used standalone
```

### Option 3: Keep Web UI Only
- The wizard already supports Two-Pi HA mode
- No CLI changes needed
- Users follow web UI flow
- Simpler maintenance

## Recommendation

**Use the existing web wizard** (Option 3) as it already has good Two-Pi HA support after our enhancements:

1. ✅ Deployment mode selection (Single vs Two-Pi HA)
2. ✅ Node role selection (Primary vs Secondary)
3. ✅ VIP configuration
4. ✅ Peer IP configuration
5. ✅ VRRP password
6. ✅ Clear help text and warnings

If CLI is desired for automation, create a separate `scripts/install-two-pi-ha.sh` that:
- Accepts arguments: `--role primary --host-ip X --peer-ip Y --vip Z --vrrp-pass P --pihole-pass Q`
- Or reads from a config file
- Or uses interactive prompts as shown above

## Example CLI Non-Interactive Usage

```bash
# On Pi1
bash scripts/install-two-pi-ha.sh \
  --role primary \
  --host-ip 192.168.8.11 \
  --peer-ip 192.168.8.12 \
  --vip 192.168.8.249 \
  --vrrp-password "SecureVRRP123!" \
  --pihole-password "SecurePihole123!"

# On Pi2
bash scripts/install-two-pi-ha.sh \
  --role secondary \
  --host-ip 192.168.8.12 \
  --peer-ip 192.168.8.11 \
  --vip 192.168.8.249 \
  --vrrp-password "SecureVRRP123!" \
  --pihole-password "SecurePihole123!"
```

This allows for complete automation while maintaining clarity.
