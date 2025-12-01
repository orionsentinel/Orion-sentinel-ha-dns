# Installation Steps - Quick Reference

> **📌 This page redirects to the main installation guide.**

For installation instructions, please see:

- **[GETTING_STARTED.md](GETTING_STARTED.md)** — Quick start guide (recommended)
- **[INSTALL.md](INSTALL.md)** — Comprehensive installation reference

---

## ⚡ Quick Installation

```bash
git clone https://github.com/orionsentinel/Orion-sentinel-ha-dns.git
cd Orion-sentinel-ha-dns
bash install.sh
```

Then open `http://<your-pi-ip>:5555` and follow the wizard.

---

## Installation Methods

| Method | Command | Best For |
|--------|---------|----------|
| **Web Wizard** | `bash install.sh` | Everyone (recommended) |
| **CLI Interactive** | `bash scripts/cli-install.sh` | Terminal users |
| **Manual** | Edit `.env` + `docker compose up` | Advanced users |

See **[INSTALL.md](INSTALL.md)** for detailed instructions on each method.
