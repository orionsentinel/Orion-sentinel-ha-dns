#!/usr/bin/env bash
# ==============================================================================
# VRRP Verification Tool for Orion Sentinel DNS HA
# ==============================================================================
# This script helps diagnose VRRP issues by checking:
# - Current keepalived state (MASTER/BACKUP/FAULT)
# - VIP presence on network interface
# - VRRP packet flow (inbound and outbound)
# - DNS resolution on node IP and VIP
#
# Usage:
#   Run on each node to verify VRRP configuration:
#   ./scripts/verify-vrrp.sh
#
#   Or run inside the keepalived container:
#   docker exec keepalived /verify-vrrp.sh
# ==============================================================================

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Default values - can be overridden by environment
VIP_ADDRESS="${VIP_ADDRESS:-192.168.8.249}"
NETWORK_INTERFACE="${NETWORK_INTERFACE:-eth1}"
PEER_IP="${PEER_IP:-}"
NODE_IP="${UNICAST_SRC_IP:-}"
CHECK_DNS_FQDN="${CHECK_DNS_FQDN:-github.com}"

echo -e "${BLUE}======================================================================${NC}"
echo -e "${BLUE}         VRRP Verification Tool - Orion Sentinel DNS HA${NC}"
echo -e "${BLUE}======================================================================${NC}"
echo ""

# ==============================================================================
# 1. Check Keepalived State
# ==============================================================================
echo -e "${BLUE}[1/5] Checking Keepalived State${NC}"
echo "----------------------------------------------------------------------"

if docker ps --format '{{.Names}}' | grep -q "^keepalived$"; then
    echo -e "${GREEN}✓${NC} Keepalived container is running"
    
    # Check for state transitions in recent logs
    echo ""
    echo "Recent state transitions:"
    docker logs keepalived 2>&1 | grep -E "Entering (MASTER|BACKUP|FAULT)" | tail -5 || echo "  (No state transitions found in recent logs)"
    
    # Get current state
    echo ""
    echo "Current state:"
    CURRENT_STATE=$(docker logs keepalived 2>&1 | grep -E "Entering (MASTER|BACKUP|FAULT)" | tail -1)
    if [[ "$CURRENT_STATE" =~ "MASTER" ]]; then
        echo -e "  ${GREEN}● MASTER${NC} - This node owns the VIP"
    elif [[ "$CURRENT_STATE" =~ "BACKUP" ]]; then
        echo -e "  ${YELLOW}● BACKUP${NC} - This node is standby"
    elif [[ "$CURRENT_STATE" =~ "FAULT" ]]; then
        echo -e "  ${RED}● FAULT${NC} - Health checks are failing"
    else
        echo -e "  ${YELLOW}● UNKNOWN${NC} - Could not determine state from logs"
    fi
else
    echo -e "${RED}✗${NC} Keepalived container is not running"
    echo "  Start with: docker compose --profile two-node-ha-primary up -d"
    echo "          or: docker compose --profile two-node-ha-backup up -d"
fi

echo ""

# ==============================================================================
# 2. Check VIP Presence on Interface
# ==============================================================================
echo -e "${BLUE}[2/5] Checking VIP Presence on ${NETWORK_INTERFACE}${NC}"
echo "----------------------------------------------------------------------"

if ip addr show "$NETWORK_INTERFACE" 2>/dev/null | grep -q "$VIP_ADDRESS"; then
    echo -e "${GREEN}✓${NC} VIP ${VIP_ADDRESS} is present on ${NETWORK_INTERFACE}"
    ip addr show "$NETWORK_INTERFACE" | grep "$VIP_ADDRESS"
else
    echo -e "${YELLOW}✗${NC} VIP ${VIP_ADDRESS} is NOT present on ${NETWORK_INTERFACE}"
    echo "  This is normal if this node is in BACKUP state"
    echo "  Current IPs on ${NETWORK_INTERFACE}:"
    ip addr show "$NETWORK_INTERFACE" 2>/dev/null | grep "inet " || echo "  (Interface not found or no IPs)"
fi

echo ""

# ==============================================================================
# 3. Check VRRP Packet Flow
# ==============================================================================
echo -e "${BLUE}[3/5] Checking VRRP Packet Flow (Proto 112)${NC}"
echo "----------------------------------------------------------------------"

# Store result for later use in summary
VRRP_PACKETS_FROM_PEER=0

if command -v tcpdump &> /dev/null; then
    echo "Capturing VRRP packets for 10 seconds on ${NETWORK_INTERFACE}..."
    echo "Looking for proto 112 (VRRP) traffic..."
    echo ""
    
    # Run tcpdump for 10 seconds and capture VRRP packets
    # Separate stdout (packet data) from stderr (warnings/errors)
    TCPDUMP_OUTPUT=$(timeout 10 tcpdump -i "$NETWORK_INTERFACE" -n proto 112 -c 20 2>/dev/null || true)
    
    if [[ -n "$TCPDUMP_OUTPUT" ]]; then
        echo "$TCPDUMP_OUTPUT"
        
        # Analyze the output
        echo ""
        
        if [[ -n "$PEER_IP" ]]; then
            # Match PEER_IP as source address (format: "IP <PEER_IP> >")
            VRRP_PACKETS_FROM_PEER=$(echo "$TCPDUMP_OUTPUT" | grep -c "IP $PEER_IP >" || true)
            
            if [[ "$VRRP_PACKETS_FROM_PEER" -gt 0 ]]; then
                echo -e "${GREEN}✓${NC} Receiving VRRP packets from peer ($PEER_IP)"
            else
                echo -e "${RED}✗${NC} NOT receiving VRRP packets from peer ($PEER_IP)"
                echo "  This indicates the peer is not sending unicast VRRP advertisements"
                echo "  Check that PEER_IP is set correctly on the other node"
            fi
        fi
        
        if [[ -n "$NODE_IP" ]]; then
            # Match NODE_IP as source address (format: "IP <NODE_IP> >")
            OUTBOUND_TO_PEER=$(echo "$TCPDUMP_OUTPUT" | grep -c "IP $NODE_IP >" || true)
            
            if [[ "$OUTBOUND_TO_PEER" -gt 0 ]]; then
                echo -e "${GREEN}✓${NC} Sending VRRP packets from this node ($NODE_IP)"
            else
                echo -e "${YELLOW}?${NC} Could not confirm outbound VRRP packets"
            fi
        fi
    else
        echo -e "${YELLOW}!${NC} No VRRP packets captured in 10 seconds"
        echo "  This could indicate:"
        echo "  - Keepalived is not running"
        echo "  - VRRP is misconfigured"
        echo "  - Wrong network interface"
    fi
else
    echo -e "${YELLOW}!${NC} tcpdump not available - skipping packet capture"
    echo "  Install with: apt-get install tcpdump"
fi

echo ""

# ==============================================================================
# 4. Check DNS Resolution (Node IP)
# ==============================================================================
echo -e "${BLUE}[4/5] Testing DNS Resolution on Node IP${NC}"
echo "----------------------------------------------------------------------"

if [[ -n "$NODE_IP" ]]; then
    # Execute dig once and capture result
    DNS_RESULT=$(dig @"$NODE_IP" "$CHECK_DNS_FQDN" +short +time=3 +tries=1 2>/dev/null | head -1)
    
    if [[ -n "$DNS_RESULT" ]]; then
        echo -e "${GREEN}✓${NC} DNS query to ${NODE_IP} successful"
        echo "  Query: $CHECK_DNS_FQDN"
        echo "  Result: $DNS_RESULT"
    else
        echo -e "${RED}✗${NC} DNS query to ${NODE_IP} FAILED"
        echo "  Query: $CHECK_DNS_FQDN"
        echo "  Check that Pi-hole is running and healthy"
    fi
else
    echo -e "${YELLOW}!${NC} NODE_IP (UNICAST_SRC_IP) not set - skipping node IP test"
fi

echo ""

# ==============================================================================
# 5. Check DNS Resolution (VIP)
# ==============================================================================
echo -e "${BLUE}[5/5] Testing DNS Resolution on VIP${NC}"
echo "----------------------------------------------------------------------"

# Execute dig once and capture result
DNS_RESULT=$(dig @"$VIP_ADDRESS" "$CHECK_DNS_FQDN" +short +time=3 +tries=1 2>/dev/null | head -1)

if [[ -n "$DNS_RESULT" ]]; then
    echo -e "${GREEN}✓${NC} DNS query to VIP ${VIP_ADDRESS} successful"
    echo "  Query: $CHECK_DNS_FQDN"
    echo "  Result: $DNS_RESULT"
else
    echo -e "${RED}✗${NC} DNS query to VIP ${VIP_ADDRESS} FAILED"
    echo "  Query: $CHECK_DNS_FQDN"
    echo "  This is expected if VIP is not active on this node (BACKUP state)"
fi

echo ""

# ==============================================================================
# Summary and Recommendations
# ==============================================================================
echo -e "${BLUE}======================================================================${NC}"
echo -e "${BLUE}                           Summary${NC}"
echo -e "${BLUE}======================================================================${NC}"
echo ""

# Determine if there are issues
HAS_ISSUES=false

if ! docker ps --format '{{.Names}}' | grep -q "^keepalived$"; then
    echo -e "${RED}⚠${NC} Keepalived is not running"
    HAS_ISSUES=true
fi

# Use previously captured VRRP packet data
if [[ -n "$PEER_IP" ]] && [[ "$VRRP_PACKETS_FROM_PEER" -eq 0 ]]; then
    echo -e "${RED}⚠${NC} Not receiving VRRP packets from peer ($PEER_IP)"
    echo "  This is the most common cause of backup becoming MASTER"
    echo "  → Check PEER_IP setting on the other node"
    echo "  → Verify firewall allows proto 112 (VRRP)"
    HAS_ISSUES=true
fi

if [[ "$HAS_ISSUES" == false ]]; then
    echo -e "${GREEN}✓${NC} No obvious issues detected"
    echo "  VRRP appears to be configured correctly"
else
    echo ""
    echo "Troubleshooting tips:"
    echo "  1. Verify both nodes have PEER_IP and UNICAST_SRC_IP set correctly"
    echo "  2. Check firewall rules allow VRRP (protocol 112)"
    echo "  3. Review keepalived logs: docker logs keepalived"
    echo "  4. Ensure both nodes use the same VRRP_PASSWORD (exactly 8 chars)"
    echo "  5. Verify network connectivity between nodes: ping <peer-ip>"
fi

echo ""
echo -e "${BLUE}======================================================================${NC}"
