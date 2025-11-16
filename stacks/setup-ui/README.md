# Web Setup UI for RPi HA DNS Stack

A modern, user-friendly web interface for installing and configuring the RPi HA DNS Stack. This replaces the need for terminal-based interactive setup scripts.

## Features

- **Prerequisites Check**: Automatically verifies system requirements
- **Hardware Survey**: Analyzes your system resources
- **Deployment Selection**: Choose from three deployment options (1Pi2P2U, 2Pi1P1U, 2Pi2P2U)
- **Network Configuration**: Easy-to-use form for network settings
- **Security Configuration**: Set passwords for Pi-hole and Grafana
- **Signal Notifications**: Optional Signal notification setup
- **Configuration Generation**: Automatically generates .env file
- **Step-by-Step Wizard**: Guided setup process with progress tracking

## Quick Start

### Option 1: Using Docker (Recommended)

```bash
# Launch the Web Setup UI
bash scripts/launch-setup-ui.sh

# Access in your browser at:
# http://localhost:5555
# or http://<your-pi-ip>:5555
```

### Option 2: Direct Python

```bash
# Install dependencies
cd stacks/setup-ui
pip install -r requirements.txt

# Run the application
python app.py

# Access in your browser at:
# http://localhost:5555
```

## Usage

1. **Prerequisites Check**: The wizard automatically checks for Docker, Docker Compose, Git, and system resources
2. **Hardware Survey**: View your system's CPU, memory, disk, and network information
3. **Select Deployment**: Choose the deployment option that fits your needs:
   - **1Pi2P2U**: Single Pi with 2 Pi-hole + 2 Unbound
   - **2Pi1P1U**: Two Pis with 1 Pi-hole + 1 Unbound each (Recommended)
   - **2Pi2P2U**: Two Pis with 2 Pi-hole + 2 Unbound each
4. **Network Configuration**: Enter your network settings (IPs, subnet, gateway)
5. **Security Configuration**: Set strong passwords for Pi-hole and Grafana
6. **Signal Notifications**: Optionally configure Signal notifications
7. **Review & Generate**: Review your configuration and generate the .env file
8. **Deploy**: Follow the provided instructions to deploy your stack

## Management Commands

```bash
# Start the Web Setup UI
bash scripts/launch-setup-ui.sh start

# Stop the Web Setup UI
bash scripts/launch-setup-ui.sh stop

# Restart the Web Setup UI
bash scripts/launch-setup-ui.sh restart

# View logs
bash scripts/launch-setup-ui.sh logs

# Check status
bash scripts/launch-setup-ui.sh status
```

## Architecture

The Web Setup UI consists of:

- **Flask Backend** (`app.py`): REST API for configuration and system checks
- **HTML/CSS/JS Frontend** (`templates/index.html`): Modern, responsive wizard interface
- **Docker Container**: Isolated environment with all dependencies

## API Endpoints

- `GET /api/prerequisites` - Check system prerequisites
- `GET /api/hardware-survey` - Get hardware information
- `GET/POST /api/network-config` - Network configuration
- `GET/POST /api/security-config` - Security settings
- `GET/POST /api/signal-config` - Signal notification settings
- `GET/POST /api/deployment-option` - Deployment option selection
- `POST /api/generate-config` - Generate .env file
- `POST /api/deploy` - Get deployment instructions

## Security Notes

- Passwords are never logged or stored in plain text
- The setup UI runs on port 5555 (not exposed to the internet by default)
- .env file is created with proper permissions
- Session data is isolated per user

## Troubleshooting

### UI won't start

```bash
# Check Docker status
docker ps

# Check logs
bash scripts/launch-setup-ui.sh logs

# Rebuild container
cd stacks/setup-ui
docker compose down
docker compose build --no-cache
docker compose up -d
```

### Can't access from browser

- Verify the service is running: `docker compose ps`
- Check firewall settings
- Try accessing from localhost first: `http://localhost:5555`

### Configuration not saving

- Check that you have write permissions in the repository directory
- Verify .env.example exists in the repository root
- Check the browser console for errors

## Comparison with Terminal Setup

| Feature | Terminal Setup | Web Setup UI |
|---------|---------------|--------------|
| Interface | Command line | Web browser |
| Prerequisites Check | ✓ | ✓ |
| Hardware Survey | ✓ | ✓ |
| Visual Feedback | Limited | Rich, colorful |
| Form Validation | Basic | Real-time |
| Navigation | Linear | Multi-step wizard |
| Remote Access | SSH required | HTTP (any device) |
| Accessibility | Terminal only | Any modern browser |

## Development

To modify the UI:

1. Edit `app.py` for backend changes
2. Edit `templates/index.html` for frontend changes
3. Restart the container: `bash scripts/launch-setup-ui.sh restart`

## License

Part of the RPi HA DNS Stack project.
