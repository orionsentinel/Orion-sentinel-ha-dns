# Security Hardening Guide

**Orion Sentinel DNS HA - Security Best Practices**

This guide covers security hardening, network exposure management, and deployment best practices to keep your DNS infrastructure secure.

---

## Table of Contents

- [Network Exposure](#network-exposure)
- [Pi-hole Security](#pi-hole-security)
- [Keepalived & VIP Security](#keepalived--vip-security)
- [Deployment Recommendations](#deployment-recommendations)
- [Access Control](#access-control)
- [Regular Maintenance](#regular-maintenance)
- [Incident Response](#incident-response)

---

## Network Exposure

### Critical Rule: Never Expose DNS to the Internet

**⚠️ WARNING:** DNS services and the Pi-hole admin panel should **NEVER** be directly exposed to the public internet.

### Why This Matters

Exposing DNS services to the internet creates serious security risks:

- **DNS Amplification Attacks**: Your server can be used in DDoS attacks
- **Information Disclosure**: Attackers can map your internal network
- **Unauthorized Access**: Admin panels become targets for brute-force attacks
- **Data Exfiltration**: DNS queries can leak information about your network activity
- **Service Abuse**: Open resolvers can be exploited for malicious purposes

### Proper Network Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    CORRECT SETUP                            │
└─────────────────────────────────────────────────────────────┘

Internet
   │
   ▼
[Router/Firewall] ← Block external DNS (port 53)
   │              ← Block Pi-hole web UI (port 80/443)
   │
   ├─────────────────────────────┐
   │                             │
   ▼                             ▼
[DNS Pi #1]                  [DNS Pi #2]
192.168.8.250                (Optional HA)
   │
   ├─ Pi-hole: 192.168.8.251/252  ← LAN ONLY
   ├─ Unbound: 192.168.8.253/254  ← LAN ONLY
   └─ VIP: 192.168.8.255          ← LAN ONLY
   │
   ▼
[LAN Devices]
Phones, PCs, IoT ← Use 192.168.8.255 as DNS
```

### Firewall Configuration

**On Your Router/Firewall:**

```bash
# BLOCK these inbound from WAN (Internet):
- Port 53 (DNS) TCP/UDP
- Port 80 (HTTP - Pi-hole web UI)
- Port 443 (HTTPS)
- Port 22 (SSH) - unless you specifically need remote access
- Port 3000 (Grafana)
- Port 9090 (Prometheus)

# ALLOW these only from LAN:
- Port 53 (DNS) - for local clients
- Port 80 (HTTP) - for Pi-hole admin access from LAN
- Port 22 (SSH) - for management from LAN
```

**iptables Example (on Pi):**

```bash
# Allow DNS only from local network
sudo iptables -A INPUT -p udp --dport 53 -s 192.168.8.0/24 -j ACCEPT
sudo iptables -A INPUT -p tcp --dport 53 -s 192.168.8.0/24 -j ACCEPT
sudo iptables -A INPUT -p udp --dport 53 -j DROP
sudo iptables -A INPUT -p tcp --dport 53 -j DROP

# Allow Pi-hole web UI only from local network
sudo iptables -A INPUT -p tcp --dport 80 -s 192.168.8.0/24 -j ACCEPT
sudo iptables -A INPUT -p tcp --dport 80 -j DROP
```

### DNS Should Only Be Reachable From

✅ **Allowed:**
- Local LAN devices (192.168.0.0/16, 10.0.0.0/8, 172.16.0.0/12)
- VPN clients (if you run WireGuard/Tailscale for remote access)
- Trusted networks only

❌ **Never Allow:**
- Direct internet exposure
- Unknown/untrusted networks
- Public IP addresses querying your DNS

### Remote Access (If Needed)

If you need remote access to Pi-hole admin panel:

**Option 1: VPN (Recommended)**
```bash
# Use WireGuard or Tailscale VPN
# See: stacks/remote-access/README.md
# Access Pi-hole through encrypted VPN tunnel
```

**Option 2: SSH Tunnel (Advanced)**
```bash
# Create SSH tunnel from remote machine
ssh -L 8080:192.168.8.251:80 pi@your-public-ip

# Access Pi-hole at http://localhost:8080/admin
```

**Option 3: Cloudflare Tunnel (Web Services Only)**
```bash
# For specific services behind authentication
# See: stacks/remote-access/README.md
# NOT recommended for DNS itself
```

---

## Pi-hole Security

### Strong Admin Password

**CRITICAL:** Use a strong, unique password for Pi-hole.

**Generate a Strong Password:**
```bash
# Generate random 32-character password
openssl rand -base64 32

# Or use passphrase
echo "MySecurePassPhrase2024!" | pihole -a -p
```

**Set Password in .env:**
```bash
# Edit .env file
PIHOLE_PASSWORD=<your-strong-password-here>

# Never use:
# - "admin" or "password"
# - Your name or simple words
# - Passwords used elsewhere
```

### Restrict Admin UI Access

**Method 1: IP Whitelisting (Pi-hole)**

Configure Pi-hole to only accept admin access from specific IPs:

```bash
# Access Pi-hole container
docker exec -it pihole_primary bash

# Edit lighttpd configuration
cat > /etc/lighttpd/conf-enabled/10-admin-whitelist.conf << 'EOF'
# Only allow admin access from these IPs
$HTTP["remoteip"] !~ "^(192\.168\.8\.|127\.0\.0\.1)" {
    $HTTP["url"] =~ "^/admin" {
        url.access-deny = ( "" )
    }
}
EOF

# Restart lighttpd
service lighttpd restart
```

**Method 2: Reverse Proxy with Authentication**

Use Nginx with basic auth:

```bash
# Install nginx and tools
sudo apt install nginx apache2-utils

# Create password file
sudo htpasswd -c /etc/nginx/.htpasswd admin

# Configure nginx reverse proxy with auth
# See stacks/remote-access/ for examples
```

**Method 3: Use SSO (Advanced)**

Deploy Authelia for single sign-on:
- See: [SSO_INTEGRATION_GUIDE.md](../SSO_INTEGRATION_GUIDE.md)
- Adds 2FA protection
- Centralized authentication

### API Token Security

**Protect Your Pi-hole API Token:**

The API token allows programmatic control of Pi-hole (blocking domains, etc.).

**Best Practices:**

1. **Store in .env File:**
   ```bash
   # In .env file
   PIHOLE_API_TOKEN=<your-api-token>
   ```

2. **Set Correct Permissions:**
   ```bash
   chmod 600 .env
   # Only owner can read/write
   ```

3. **Never Commit to Git:**
   ```bash
   # Ensure .env is in .gitignore
   echo ".env" >> .gitignore
   ```

4. **Rotate Regularly:**
   ```bash
   # Generate new token periodically
   # In Pi-hole web UI: Settings → API → Generate new token
   ```

5. **Limit Access:**
   - Only Security Pi (Orion NSM AI) should use the API
   - Don't expose API token in logs or scripts
   - Use environment variables, never hardcode

**Getting Your API Token:**
```bash
# Option 1: From Pi-hole web UI
# Settings → API → Show API Token

# Option 2: From Pi-hole container
docker exec pihole_primary cat /etc/pihole/setupVars.conf | grep WEBPASSWORD
```

---

## Keepalived & VIP Security

### Virtual IP (VIP) Security

**The VIP should only be accessible on trusted LAN.**

**Key Points:**

1. **Single MASTER Node:**
   - Only one node should be MASTER at a time
   - If both nodes become MASTER (split-brain), DNS can become inconsistent
   - Monitor Keepalived logs for unexpected MASTER transitions

2. **VRRP Password:**
   ```bash
   # Set strong VRRP password in .env
   VRRP_PASSWORD=$(openssl rand -base64 20)
   
   # This prevents rogue nodes from joining the cluster
   ```

3. **VRRP Traffic:**
   - Keepalived uses multicast (224.0.0.18)
   - Ensure your network switch supports multicast
   - Don't block VRRP (protocol 112) between nodes

4. **Network Isolation:**
   - VIP should be on the same LAN as your devices
   - Never expose VIP to untrusted networks
   - Use VLAN segmentation if needed

### Monitoring MASTER/BACKUP State

**Check Current State:**
```bash
# View Keepalived logs
docker logs keepalived | tail -50

# Look for:
# "Entering MASTER STATE" - This node is active
# "Entering BACKUP STATE" - This node is standby
```

**Set Up Alerts:**
```bash
# Monitor state transitions
# Unexpected MASTER changes could indicate:
# - Network issues
# - Hardware failure
# - Attack attempt

# See: docs/observability.md for alerting setup
```

### Prevent Split-Brain

**Split-brain:** Both nodes think they're MASTER simultaneously.

**Prevention:**

1. **Ensure Reliable Network:**
   - Use quality network switches
   - Avoid wireless connections between HA nodes
   - Monitor network latency

2. **Configure Proper Priorities:**
   ```bash
   # In keepalived.conf
   # Primary node: priority 100
   # Secondary node: priority 90
   ```

3. **Health Checks:**
   - Keepalived should check service health
   - Unhealthy node should transition to BACKUP
   - See: `stacks/dns/keepalived/check_dns.sh`

---

## Deployment Recommendations

### Hardware Security

**Use Static IP Addresses:**

```bash
# Configure static IPs for both Pis
# /etc/dhcpcd.conf or via router DHCP reservation

interface eth0
static ip_address=192.168.8.250/24
static routers=192.168.8.1
static domain_name_servers=1.1.1.1 8.8.8.8
```

**Benefits:**
- Predictable network configuration
- Easier firewall rules
- Consistent VIP behavior
- Simplified monitoring

### Network Segmentation

**Isolate DNS Infrastructure (Advanced):**

```
[Router]
   │
   ├─ VLAN 10: Management (SSH, Admin UIs)
   ├─ VLAN 20: DNS Services (Port 53)
   └─ VLAN 30: Client Devices
```

**Firewall Rules:**
- VLAN 10: Access from admin workstation only
- VLAN 20: DNS queries from VLAN 30 only
- VLAN 30: Cannot access VLAN 10

### Physical Security

- **Secure Physical Access:** Keep Raspberry Pis in a locked area
- **Power Protection:** Use UPS to prevent sudden shutdowns
- **Temperature Monitoring:** Ensure adequate cooling
- **Backup Power:** Consider battery backup for critical infrastructure

### OS Hardening

**Regular Updates:**
```bash
# Update OS weekly
sudo apt update && sudo apt upgrade -y

# Enable automatic security updates
sudo apt install unattended-upgrades
sudo dpkg-reconfigure -plow unattended-upgrades
```

**Disable Unnecessary Services:**
```bash
# List running services
systemctl list-units --type=service --state=running

# Disable unused services
sudo systemctl disable <service-name>
```

**SSH Hardening:**
```bash
# Edit /etc/ssh/sshd_config
PermitRootLogin no
PasswordAuthentication no  # Use SSH keys only
Port 2222  # Change default port
AllowUsers pi  # Limit allowed users

# Restart SSH
sudo systemctl restart ssh
```

**Firewall (UFW):**
```bash
# Install and configure UFW
sudo apt install ufw

# Default deny
sudo ufw default deny incoming
sudo ufw default allow outgoing

# Allow SSH (from LAN only)
sudo ufw allow from 192.168.8.0/24 to any port 22

# Allow DNS (from LAN only)
sudo ufw allow from 192.168.8.0/24 to any port 53

# Enable firewall
sudo ufw enable
```

---

## Access Control

### Principle of Least Privilege

**Only grant access to those who need it:**

1. **SSH Access:**
   - Use SSH keys, not passwords
   - One key per person/device
   - Revoke keys when no longer needed

2. **Pi-hole Admin:**
   - Don't share the admin password
   - Use separate accounts if multiple admins needed
   - Consider SSO with individual accounts

3. **API Access:**
   - Only Security Pi should have API token
   - Rotate token if compromised
   - Monitor API usage

### Audit Logging

**Enable and Monitor Logs:**

```bash
# Check Pi-hole query logs
docker exec pihole_primary tail -f /var/log/pihole.log

# Check system auth logs
sudo tail -f /var/log/auth.log

# Monitor failed login attempts
sudo grep "Failed password" /var/log/auth.log
```

**Log Retention:**
- Keep logs for at least 30 days
- Archive important logs off-site
- Set up log rotation to prevent disk fill

---

## Regular Maintenance

### Security Updates

**Weekly:**
- Check for OS updates: `sudo apt update && sudo apt upgrade`
- Check for Docker image updates: `bash scripts/upgrade.sh`
- Review security advisories

**Monthly:**
- Review access logs for anomalies
- Audit user accounts and SSH keys
- Test backup restore procedure
- Verify firewall rules are current

**Quarterly:**
- Full security audit
- Penetration testing (if applicable)
- Review and update passwords
- Update documentation

### Vulnerability Scanning

**Scan for Known Vulnerabilities:**

```bash
# Scan Docker images
docker run --rm -v /var/run/docker.sock:/var/run/docker.sock \
  aquasec/trivy image pihole/pihole:latest

# Check for rootkits
sudo apt install rkhunter
sudo rkhunter --check
```

---

## Incident Response

### If You Suspect a Breach

**Immediate Actions:**

1. **Isolate the System:**
   ```bash
   # Disconnect from network
   sudo ifconfig eth0 down
   ```

2. **Review Logs:**
   ```bash
   # Check for unauthorized access
   sudo grep "Accepted" /var/log/auth.log
   sudo grep "Failed" /var/log/auth.log
   
   # Check Pi-hole logs for unusual queries
   docker exec pihole_primary tail -1000 /var/log/pihole.log
   ```

3. **Change Passwords:**
   ```bash
   # Change Pi-hole admin password
   docker exec -it pihole_primary pihole -a -p
   
   # Change user passwords
   sudo passwd pi
   ```

4. **Restore from Known-Good Backup:**
   ```bash
   bash scripts/restore-config.sh backups/dns-ha-backup-<date>.tar.gz
   ```

5. **Document Everything:**
   - What you observed
   - Actions taken
   - Lessons learned

### Post-Incident Review

After resolving an incident:

1. **Root Cause Analysis:** Determine how breach occurred
2. **Implement Fixes:** Address vulnerabilities
3. **Update Procedures:** Improve security practices
4. **Training:** Educate team members
5. **Monitor:** Increase monitoring for similar patterns

---

## Security Checklist

Use this checklist to verify your deployment is secure:

### Network Security
- [ ] DNS (port 53) is NOT exposed to the internet
- [ ] Pi-hole web UI (port 80) is NOT exposed to the internet
- [ ] SSH (port 22) is only accessible from trusted IPs
- [ ] Firewall rules are configured and tested
- [ ] VIP is only accessible on trusted LAN
- [ ] Router blocks inbound DNS from WAN

### Authentication & Access
- [ ] Strong Pi-hole admin password (32+ characters)
- [ ] SSH key-based authentication enabled
- [ ] Password authentication disabled for SSH
- [ ] API token stored securely in .env with proper permissions
- [ ] Root login via SSH disabled

### Keepalived & HA
- [ ] VRRP password is strong and unique
- [ ] Only one node is MASTER at any time
- [ ] VIP failover tested and working
- [ ] Health checks configured and working
- [ ] VRRP traffic not blocked by firewall

### System Hardening
- [ ] OS fully updated
- [ ] Automatic security updates enabled
- [ ] Unnecessary services disabled
- [ ] UFW firewall enabled and configured
- [ ] Fail2ban installed (optional but recommended)

### Monitoring & Maintenance
- [ ] Automated backups configured (weekly minimum)
- [ ] Backup restore tested successfully
- [ ] Log monitoring enabled
- [ ] Security updates checked weekly
- [ ] Incident response plan documented

### Documentation
- [ ] Network diagram created
- [ ] IP addresses documented
- [ ] Passwords stored in password manager
- [ ] Emergency procedures documented
- [ ] Team members trained

---

## Additional Resources

- **Pi-hole Security:** https://docs.pi-hole.net/main/security/
- **Docker Security:** https://docs.docker.com/engine/security/
- **Raspberry Pi Hardening:** https://www.raspberrypi.org/documentation/configuration/security.md
- **OWASP Top 10:** https://owasp.org/www-project-top-ten/

---

## Getting Help

If you discover a security vulnerability:

1. **Do NOT open a public GitHub issue**
2. Email the maintainers privately
3. Include details about the vulnerability
4. Allow time for a patch before public disclosure

For security questions:
- Review: [SECURITY_GUIDE.md](../SECURITY_GUIDE.md)
- Check: [TROUBLESHOOTING.md](../TROUBLESHOOTING.md)
- Ask: GitHub Discussions (for general questions)

---

**Last Updated:** 2024-11-20

**Remember:** Security is a continuous process, not a one-time task. Regular monitoring, updates, and audits are essential for maintaining a secure DNS infrastructure.
