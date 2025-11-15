# RPi HA DNS Stack 🌐

A high-availability DNS stack running on Raspberry Pi 5.

## Network Configuration 🛠️
- **Host (Raspberry Pi) IP:** 192.168.8.240 (eth0)
- **Primary DNS:** 192.168.8.241 (pihole1 + unbound1)
- **Secondary DNS:** 192.168.8.242 (pihole2 + unbound2)
- **Keepalived VIP:** 192.168.8.245

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
[192.168.8.240] <- Raspberry Pi
     |         |
     |         |
[192.168.8.241] [192.168.8.242]
 Pi-hole 1     Pi-hole 2
     |         |
     |         |
[192.168.8.245] <- Keepalived VIP

```

## Features List 📝
- High availability through Keepalived.
- Enhanced security and performance using Unbound.
- Real-time observability with Prometheus and Grafana.
- Automated sync of DNS records with Gravity Sync.
- Self-healing through AI-Watchdog.

## Quick Start Instructions 🚀

### Option 1: Interactive Setup (Recommended)
Run the interactive setup script that will guide you through configuration:
```bash
git clone https://github.com/yorgosroussakis/rpi-ha-dns-stack.git
cd rpi-ha-dns-stack
bash scripts/setup.sh
```

The setup script will:
- Guide you through network configuration
- Set up passwords securely
- Configure Signal notifications (optional)
- Deploy the stack automatically

### Option 2: Manual Setup
1. Clone the repository:
   ```bash
   git clone https://github.com/yorgosroussakis/rpi-ha-dns-stack.git
   cd rpi-ha-dns-stack
   ```
2. Set up Signal notifications (optional but recommended):
   - Send "I allow callmebot to send me messages" to **+34 644 51 38 46** on Signal
   - You will receive your API key in response
   - Copy `.env.example` to `.env` and update:
     - `SIGNAL_PHONE_NUMBER`: Your phone number with country code (e.g., +1234567890)
     - `SIGNAL_API_KEY`: The API key you received from CallMeBot

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
- **Pi-hole Dashboard:** [http://192.168.8.241/admin](http://192.168.8.241/admin)
- **Metrics Dashboard (Grafana):** [http://192.168.8.240:3000](http://192.168.8.240:3000)
- **Prometheus:** [http://192.168.8.240:9090](http://192.168.8.240:9090)
- **Alertmanager:** [http://192.168.8.240:9093](http://192.168.8.240:9093)
- **Signal Webhook Bridge:** [http://192.168.8.240:8080/health](http://192.168.8.240:8080/health)

## Signal Notifications 📱
The stack uses CallMeBot as a hosted Signal webhook bridge to send alerts:
- **Container restart notifications** from AI-Watchdog
- **Prometheus alerts** via Alertmanager
- **Test notifications** via API endpoint

To test Signal notifications:
```bash
curl -X POST http://192.168.8.240:8080/test \
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