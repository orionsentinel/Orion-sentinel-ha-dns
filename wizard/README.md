# First-Run Web Wizard

A minimal Flask-based web application for guiding users through the initial setup of Orion Sentinel DNS HA stack.

## Overview

The wizard provides a simple web interface for configuring the DNS stack without editing YAML files:

1. **Welcome** - Introduction to the stack
2. **Network Configuration** - Set deployment mode, IP addresses, and passwords
3. **Profile Selection** - Choose DNS filtering level
4. **Setup Complete** - Next steps and deployment instructions

## Quick Start

### Standalone Mode

Run the wizard before deploying the full stack:

```bash
# Install dependencies
pip3 install -r requirements.txt

# Start wizard
python3 app.py
```

Access at: `http://localhost:8080` or `http://<pi-ip>:8080`

### Docker Mode

The wizard can run as part of the DNS stack:

```bash
# Deploy with wizard profile
cd ../stacks/dns
docker compose --profile wizard up -d
```

Access at: `http://<pi-ip>:8080`

## Features

- ✅ **Single-Node Mode**: Configure for one Raspberry Pi
- ✅ **Two-Node HA Mode**: Configure for high availability with two Pis
- ✅ **DNS Profiles**: Choose from Standard, Family, or Paranoid filtering
- ✅ **Configuration Generation**: Automatically creates `.env` file
- ✅ **Validation**: Validates user input before saving
- ✅ **Sentinel File**: Prevents accidental re-configuration

## File Structure

```
wizard/
├── app.py                      # Flask application
├── requirements.txt            # Python dependencies
├── Dockerfile                  # Docker container build
├── static/
│   └── style.css              # CSS styling
└── templates/
    ├── welcome.html           # Welcome page
    ├── network_config.html    # Network configuration
    ├── profile_selection.html # Profile selection
    └── setup_complete.html    # Completion page
```

## Configuration Flow

1. **User accesses wizard** at http://<pi-ip>:8080
2. **Wizard checks** for `.setup_done` sentinel file
   - If exists: Show "Setup Complete" page
   - If not exists: Show welcome page
3. **User configures**:
   - Deployment mode (single-node or HA)
   - Network settings (Pi IP, interface, VIP for HA)
   - Security (Pi-hole password)
4. **Wizard updates** `.env` file with configuration
5. **User selects** DNS profile (Standard/Family/Paranoid)
6. **Wizard creates** `.setup_done` sentinel file
7. **User follows** deployment instructions on completion page

## API Endpoints

### `GET /`
Main page - shows welcome or setup complete

### `GET /network`
Network configuration form

### `POST /api/network`
Save network configuration to `.env`

**Request:**
```json
{
  "mode": "single|ha",
  "pi_ip": "192.168.8.250",
  "interface": "eth0",
  "pihole_password": "SecurePassword123!",
  "vip": "192.168.8.255",       // HA mode only
  "node_role": "MASTER|BACKUP"  // HA mode only
}
```

**Response:**
```json
{
  "success": true
}
```

### `GET /profile`
Profile selection page

### `POST /api/profile`
Save selected profile

**Request:**
```json
{
  "profile": "standard|family|paranoid"
}
```

**Response:**
```json
{
  "success": true,
  "profile": "standard"
}
```

### `GET /health`
Health check endpoint

**Response:**
```json
{
  "status": "ok",
  "setup_done": false
}
```

## Environment Variables

The wizard reads and writes to the `.env` file in the repository root:

**Single-Node Mode:**
- `HOST_IP` - Pi's IP address
- `VIP_ADDRESS` - Set to same as HOST_IP
- `NETWORK_INTERFACE` - Network interface (e.g., eth0)
- `PIHOLE_PASSWORD` - Pi-hole admin password
- `NODE_ROLE` - Set to MASTER

**HA Mode:**
- `HOST_IP` - This Pi's IP address
- `VIP_ADDRESS` - Shared virtual IP
- `NETWORK_INTERFACE` - Network interface
- `PIHOLE_PASSWORD` - Pi-hole admin password (must match on both Pis)
- `NODE_ROLE` - MASTER or BACKUP

## Re-running the Wizard

To reconfigure:

1. Delete the sentinel file:
   ```bash
   rm wizard/.setup_done
   ```

2. Restart the wizard:
   ```bash
   python3 wizard/app.py
   ```

3. Access at `http://<pi-ip>:8080`

**Note:** The wizard will overwrite values in `.env`. Consider backing up first:
```bash
cp .env .env.backup
```

## Disabling the Wizard

After initial setup, you can disable the wizard service:

```bash
# Stop the container
docker compose --profile wizard down dns-wizard

# Or remove from docker-compose.yml
```

## Security Considerations

- **Port 8080** is exposed on the local network
- Only run during initial setup
- Use strong passwords (minimum 8 characters)
- `.env` file contains sensitive credentials
- Ensure proper file permissions: `chmod 600 .env`
- Do not expose port 8080 to the internet

## Troubleshooting

### Wizard not accessible

Check if running:
```bash
# Standalone
ps aux | grep wizard/app.py

# Docker
docker ps | grep dns-wizard
```

Check from Pi:
```bash
curl http://localhost:8080/health
```

### Configuration not saving

Check file permissions:
```bash
ls -la ../.env
chmod 644 ../.env
```

### Templates not loading

Ensure templates directory exists:
```bash
ls -la templates/
```

## Development

### Running in Debug Mode

```bash
export FLASK_ENV=development
export FLASK_DEBUG=1
python3 app.py
```

### Testing

```bash
# Test welcome page
curl http://localhost:8080/

# Test health endpoint
curl http://localhost:8080/health

# Test network API
curl -X POST http://localhost:8080/api/network \
  -H "Content-Type: application/json" \
  -d '{"mode":"single","pi_ip":"192.168.8.250","interface":"eth0","pihole_password":"test123"}'
```

## Documentation

- **[First-Run Wizard Guide](../docs/first-run-wizard.md)** - Complete usage documentation
- **[Single Pi Installation](../docs/install-single-pi.md)** - CLI guide for single Pi
- **[Two Pi HA Installation](../docs/install-two-pi-ha.md)** - CLI guide for HA mode
- **[Profiles Guide](../docs/profiles.md)** - DNS profile documentation

## License

Part of Orion Sentinel DNS HA project.

## Support

For issues or questions:
1. Check [First-Run Wizard Guide](../docs/first-run-wizard.md)
2. Review [Troubleshooting Guide](../TROUBLESHOOTING.md)
3. Open an issue on GitHub
