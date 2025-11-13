# RPi HA DNS Stack 🌐

A high-availability DNS stack running on Raspberry Pi 5.

## Network Configuration 🛠️
- **Host (Raspberry Pi) IP:** 192.168.7.240 (eth0)
- **Primary DNS:** 192.168.7.241 (pihole1 + unbound1)
- **Secondary DNS:** 192.168.7.242 (pihole2 + unbound2)
- **Keepalived VIP:** 192.168.7.245

## Stack Includes:
- Dual Pi-hole v6 instances with Unbound recursive DNS.
- Keepalived for HA failover.
- Gravity Sync for Pi-hole synchronization.
- AI-Watchdog for self-healing.
- Prometheus + Grafana + Alertmanager + Loki for observability.
- Signal notifications (webhook placeholder).
- Nebula mesh VPN.
- Docker + Portainer setup.

## ASCII Network Diagram 🖥️
```plaintext
[192.168.7.240] <- Raspberry Pi
     |         |
     |         |
[192.168.7.241] [192.168.7.242]
 Pi-hole 1     Pi-hole 2
     |         |
     |         |
[192.168.7.245] <- Keepalived VIP

```

## Features List 📝
- High availability through Keepalived.
- Enhanced security and performance using Unbound.
- Real-time observability with Prometheus and Grafana.
- Automated sync of DNS records with Gravity Sync.
- Self-healing through AI-Watchdog.

## Quick Start Instructions 🚀
1. Clone the repository:
   ```bash
   git clone https://github.com/yorgosroussakis/rpi-ha-dns-stack.git
   cd rpi-ha-dns-stack
   ```
2. Deploy the stack using Docker Compose:
   ```bash
   docker-compose up -d
   ```

## Service Access URLs 🌐
- **Pi-hole Dashboard:** [http://192.168.7.241/admin](http://192.168.7.241/admin)
- **Metrics Dashboard (Grafana):** [http://192.168.7.240:3000](http://192.168.7.240:3000)

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