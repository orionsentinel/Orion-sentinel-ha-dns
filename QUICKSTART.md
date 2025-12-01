# Quick Start Guide 🚀

> **📌 For a complete guide, see [GETTING_STARTED.md](GETTING_STARTED.md)**

---

## One-Command Installation

```bash
git clone https://github.com/orionsentinel/Orion-sentinel-ha-dns.git
cd Orion-sentinel-ha-dns
bash install.sh
```

Then open `http://<your-pi-ip>:5555` and follow the wizard.

---

## After Installation

### Access Services

| Service | URL |
|---------|-----|
| Pi-hole Primary | `http://<your-ip>/admin` |
| Grafana | `http://<your-ip>:3000` |

### Configure Router DNS

Set your router's DNS to your Pi's IP address.

### Apply Security Profile

```bash
python3 scripts/apply-profile.py --profile standard
```

---

## Quick Commands

```bash
# Check status
docker ps

# Test DNS
dig @<your-ip> google.com

# Health check
bash scripts/health-check.sh
```

---

## Troubleshooting

| Problem | Solution |
|---------|----------|
| Docker permission errors | `sudo usermod -aG docker $USER && newgrp docker` |
| Services won't start | `docker compose -f stacks/dns/docker-compose.yml logs` |
| DNS not resolving | Check container logs, verify network config |

See **[TROUBLESHOOTING.md](TROUBLESHOOTING.md)** for more solutions.

---

## Documentation

- **[GETTING_STARTED.md](GETTING_STARTED.md)** — Full setup guide
- **[INSTALL.md](INSTALL.md)** — Comprehensive installation
- **[USER_GUIDE.md](USER_GUIDE.md)** — Daily operations
- **[TROUBLESHOOTING.md](TROUBLESHOOTING.md)** — Common issues
