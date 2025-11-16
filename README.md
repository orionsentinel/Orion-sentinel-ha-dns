# RPi HA DNS Stack 🌐

A high-availability DNS stack running on Raspberry Pi 5.

## 🆕 Choose Your Deployment Option!

This repository now supports **THREE complete deployment options** for different High Availability scenarios:

### **[📂 View All Deployment Options →](deployments/)**

| Option | Description | Best For |
|--------|-------------|----------|
| **[HighAvail_1Pi2P2U](deployments/HighAvail_1Pi2P2U/)** | 1 Pi with 2 Pi-hole + 2 Unbound | Home labs, Testing |
| **[HighAvail_2Pi1P1U](deployments/HighAvail_2Pi1P1U/)** ⭐ | 2 Pis with 1 Pi-hole + 1 Unbound each | **Production** (RECOMMENDED) |
| **[HighAvail_2Pi2P2U](deployments/HighAvail_2Pi2P2U/)** | 2 Pis with 2 Pi-hole + 2 Unbound each | Mission-Critical |

Each deployment option includes complete docker-compose files, configurations, and detailed instructions.

**Architecture Documentation:**
- **[📑 Documentation Index](MULTI_NODE_INDEX.md)** - Navigation guide
- **[🚀 Quick Start](MULTI_NODE_QUICKSTART.md)** - Overview
- **[📐 Architecture Design](MULTI_NODE_HA_DESIGN.md)** - Detailed design
- **[🎨 Visual Comparison](ARCHITECTURE_COMPARISON.md)** - Diagrams

## Network Configuration 🛠️
- **Host (Raspberry Pi) IP:** 192.168.8.250 (eth0)
- **Primary DNS:** 192.168.8.251 (pihole_primary)
- **Secondary DNS:** 192.168.8.252 (pihole_secondary)
- **Primary Unbound:** 192.168.8.253 (unbound_primary)
- **Secondary Unbound:** 192.168.8.254 (unbound_secondary)
- **Keepalived VIP:** 192.168.8.255

## Stack Includes:
- Dual Pi-hole v6 instances with Unbound recursive DNS.
- Keepalived for HA failover.
- Gravity Sync for Pi-hole synchronization.
- AI-Watchdog for self-healing with Signal notifications.
- Prometheus + Grafana + Alertmanager + Loki for observability.
- Signal webhook bridge for notifications via CallMeBot.
- Nebula mesh VPN.
- Docker + Portainer setup.

## ASCII Network Diagram 🖥️
```plaintext
[192.168.8.250] <- Raspberry Pi Host
     |         |
     |         |
[192.168.8.251] [192.168.8.252]
 Pi-hole 1     Pi-hole 2
     |         |
     |         |
[192.168.8.253] [192.168.8.254]
 Unbound 1    Unbound 2
     |         |
     |         |
[192.168.8.255] <- Keepalived VIP

```

## Deployment Options 🎯

This repository provides **three complete deployment configurations**:

### HighAvail_1Pi2P2U - Single Pi Setup
- **Architecture:** 1 Pi with 2 Pi-hole + 2 Unbound
- **Redundancy:** Container-level only
- **Best for:** Home labs, testing, single Pi setups
- **Hardware:** 1x Raspberry Pi (4GB+ RAM)
- **[View Details →](deployments/HighAvail_1Pi2P2U/)**

### HighAvail_2Pi1P1U - Simplified Two-Pi Setup ⭐ RECOMMENDED
- **Architecture:** 2 Pis with 1 Pi-hole + 1 Unbound each
- **Redundancy:** Hardware + Node-level
- **Best for:** Production home networks, small offices
- **Hardware:** 2x Raspberry Pi (4GB+ RAM each)
- **[View Details →](deployments/HighAvail_2Pi1P1U/)**

### HighAvail_2Pi2P2U - Full Redundancy Two-Pi Setup
- **Architecture:** 2 Pis with 2 Pi-hole + 2 Unbound each
- **Redundancy:** Container + Hardware + Node-level (triple)
- **Best for:** Mission-critical environments
- **Hardware:** 2x Raspberry Pi (8GB RAM recommended)
- **[View Details →](deployments/HighAvail_2Pi2P2U/)**

**Quick Decision:** Have 2 Pis? → Use **HighAvail_2Pi1P1U** ⭐  
**[See Full Comparison →](deployments/)**

## Features List 📝
- High availability through Keepalived.
- Enhanced security and performance using Unbound.
- Real-time observability with Prometheus and Grafana.
- Automated sync of DNS records with Gravity Sync.
- Self-healing through AI-Watchdog.
- **🆕 Multi-node deployment for true hardware redundancy.**

## Quick Start Instructions 🚀

### 🌟 NEW: Web Setup UI (Easiest!) ✨

**Now with a graphical web interface!** No more terminal commands - just point and click.

The Web Setup UI provides:
- ✅ Modern, user-friendly web interface
- ✅ Automatic prerequisites checking (Docker, RAM, disk space)
- ✅ Hardware survey with detailed system information
- ✅ Visual deployment option selection
- ✅ Form-based network and security configuration
- ✅ Real-time validation and feedback
- ✅ Configuration summary and deployment instructions
- ✅ Access from any device on your network

```bash
git clone https://github.com/yorgosroussakis/rpi-ha-dns-stack.git
cd rpi-ha-dns-stack
bash scripts/launch-setup-ui.sh
```

**Then open your browser at:** `http://localhost:5555` or `http://<your-pi-ip>:5555`

**That's it!** Follow the step-by-step wizard in your browser - no terminal knowledge required!

---

### Alternative: Terminal-Based Setup

#### Option 1: Interactive Terminal Wizard

If you prefer a terminal-based interactive wizard:
```bash
git clone https://github.com/yorgosroussakis/rpi-ha-dns-stack.git
cd rpi-ha-dns-stack
bash scripts/interactive-setup.sh
```

#### Option 2: Guided Terminal Setup

For a simpler guided terminal setup:
```bash
git clone https://github.com/yorgosroussakis/rpi-ha-dns-stack.git
cd rpi-ha-dns-stack
bash scripts/setup.sh
```

#### Option 3: Manual Setup
1. Clone the repository:
   ```bash
   git clone https://github.com/yorgosroussakis/rpi-ha-dns-stack.git
   cd rpi-ha-dns-stack
   ```
2. Set up Signal notifications (optional but recommended):
   - Follow the detailed guide in [SIGNAL_INTEGRATION_GUIDE.md](SIGNAL_INTEGRATION_GUIDE.md)
   - Quick start: Register a phone number with signal-cli-rest-api
   - Copy `.env.example` to `.env` and update:
     - `SIGNAL_NUMBER`: Your phone number registered with Signal (e.g., +1234567890)
     - `SIGNAL_RECIPIENTS`: Recipient phone numbers (comma-separated)

3. Deploy the stack:
   ```bash
   bash scripts/install.sh
   ```

## Updating the Stack 🔄
To update your installation when the repository is updated:
```bash
cd rpi-ha-dns-stack
bash scripts/update.sh
```

The update script will:
- Backup your current configuration
- Pull latest changes from git
- Rebuild updated containers
- Restart services with zero downtime
- Preserve your `.env` and override files

## Service Access URLs 🌐
- **🆕 Web Setup UI:** [http://192.168.8.250:5555](http://192.168.8.250:5555) - Installation & Configuration Interface
- **Pi-hole Primary Dashboard:** [http://192.168.8.251/admin](http://192.168.8.251/admin)
- **Pi-hole Secondary Dashboard:** [http://192.168.8.252/admin](http://192.168.8.252/admin)
- **Metrics Dashboard (Grafana):** [http://192.168.8.250:3000](http://192.168.8.250:3000)
- **Prometheus:** [http://192.168.8.250:9090](http://192.168.8.250:9090)
- **Alertmanager:** [http://192.168.8.250:9093](http://192.168.8.250:9093)
- **Signal CLI REST API:** [http://192.168.8.250:8081](http://192.168.8.250:8081)
- **Signal Webhook Bridge:** [http://192.168.8.250:8080/health](http://192.168.8.250:8080/health)

## Signal Notifications 📱
The stack uses [signal-cli-rest-api](https://github.com/bbernhard/signal-cli-rest-api) for self-hosted Signal notifications:
- **Container restart notifications** from AI-Watchdog
- **Prometheus alerts** via Alertmanager
- **Test notifications** via API endpoint
- **End-to-end encrypted** using Signal protocol
- **No third-party dependencies** - fully self-hosted

For detailed setup instructions, see [SIGNAL_INTEGRATION_GUIDE.md](SIGNAL_INTEGRATION_GUIDE.md)

To test Signal notifications:
```bash
curl -X POST http://192.168.8.250:8080/test \
  -H "Content-Type: application/json" \
  -d '{"message": "Test from RPi HA DNS Stack"}'
```

## Health Check Commands ✅
- Check Pi-hole status:
  ```bash
  pihole status
  ```
- Check Unbound status:
  ```bash
  systemctl status unbound
  ```

## Configuration Details ⚙️
- [Pi-hole Configuration](https://docs.pi-hole.net/)  
- [Unbound Configuration](https://nlnetlabs.nl/projects/unbound/about/)  
- [Keepalived Documentation](https://www.keepalived.org/)  
- [Prometheus Documentation](https://prometheus.io/docs/introduction/overview/)  

## Conclusion 🏁
This README provides all necessary information to configure and run a high-availability DNS stack using Raspberry Pi 5. Enjoy a reliable and powerful DNS solution!