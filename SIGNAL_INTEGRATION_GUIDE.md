# Signal Webhook Integration - Quick Reference

## What Was Done

This PR integrates a hosted Signal webhook bridge using CallMeBot API to enable real-time Signal notifications for the RPi HA DNS Stack.

## Key Features

✅ **Alertmanager Integration** - Prometheus alerts are sent to Signal
✅ **AI-Watchdog Notifications** - Container restart notifications via Signal
✅ **Test Endpoint** - Easy way to test notifications
✅ **Health Monitoring** - Health check endpoints for all services
✅ **Hosted Solution** - No need to self-host Signal infrastructure

## Architecture

```
Alertmanager/AI-Watchdog → Signal Bridge → CallMeBot API → Signal App
```

## New Files

- `stacks/observability/signal-webhook-bridge/app.py` - Flask webhook bridge
- `stacks/observability/signal-webhook-bridge/Dockerfile` - Container image
- `scripts/test-signal-integration.sh` - Automated test suite (11 tests)
- `scripts/deployment-readiness-check.sh` - Pre-deployment verification (14 checks)
- `QA_TEST_RESULTS.md` - Comprehensive QA documentation
- `.gitignore` - Python cache exclusions

## Modified Files

- `.env.example` - Added SIGNAL_API_KEY and CallMeBot instructions
- `README.md` - Added Signal setup instructions and service URLs
- `stacks/observability/docker-compose.yml` - Added signal-webhook-bridge service
- `stacks/observability/alertmanager/alertmanager.yml` - Configured Signal receiver
- `stacks/ai-watchdog/app.py` - Added Signal notification on container restart
- `stacks/ai-watchdog/Dockerfile` - Added requests library
- `stacks/ai-watchdog/docker-compose.yml` - Added Signal bridge connection

## Setup Instructions

### 1. Get CallMeBot API Key
Send this message on Signal to **+34 644 51 38 46**:
```
I allow callmebot to send me messages
```
You'll receive your API key in response.

### 2. Configure Environment
```bash
cp .env.example .env
# Edit .env and set:
# - SIGNAL_PHONE_NUMBER=+1234567890  (your number with country code)
# - SIGNAL_API_KEY=your-api-key-here (from CallMeBot)
```

### 3. Deploy Services
```bash
# Deploy observability stack (includes Signal bridge)
cd stacks/observability
docker compose up -d

# Deploy AI-watchdog
cd ../ai-watchdog
docker compose up -d
```

### 4. Test Notification
```bash
curl -X POST http://192.168.8.240:8080/test \
  -H "Content-Type: application/json" \
  -d '{"message": "Test notification from RPi HA DNS Stack"}'
```

You should receive a Signal message on your phone!

## Service Endpoints

| Service | URL | Purpose |
|---------|-----|---------|
| Signal Bridge Health | http://192.168.8.240:8080/health | Health check |
| Signal Bridge Test | http://192.168.8.240:8080/test | Send test notification |
| Alertmanager | http://192.168.8.240:9093 | View alerts |
| Prometheus | http://192.168.8.240:9090 | Metrics & alerting |

## Testing

Run automated tests:
```bash
# Run integration tests (11 tests)
bash scripts/test-signal-integration.sh

# Run deployment readiness check (14 checks)
bash scripts/deployment-readiness-check.sh
```

## How It Works

### Alertmanager Flow
1. Prometheus detects an issue and fires an alert
2. Alert is sent to Alertmanager
3. Alertmanager sends webhook to signal-webhook-bridge
4. Bridge formats the message and sends to CallMeBot API
5. CallMeBot delivers message via Signal protocol
6. User receives notification on their phone

### AI-Watchdog Flow
1. AI-Watchdog detects a stopped container
2. Container is restarted
3. Watchdog sends notification to signal-webhook-bridge
4. Bridge forwards to CallMeBot API
5. User receives restart notification

## Notification Examples

**Container Restart:**
```
🔧 AI-Watchdog: Restarted containers: pihole1, unbound1
```

**Prometheus Alert:**
```
🔴 HighMemoryUsage
Status: FIRING
Severity: WARNING
Description: Container memory usage is above 90%
```

## Security Notes

- ✅ API keys stored in `.env` (not committed to git)
- ✅ `.env` added to `.gitignore`
- ✅ Credentials passed via environment variables
- ✅ CallMeBot uses HTTPS
- ✅ No sensitive data in logs

## Troubleshooting

### No notifications received?
1. Check Signal bridge health: `curl http://192.168.8.240:8080/health`
2. Verify API key is correct in `.env`
3. Check container logs: `docker logs signal-webhook-bridge`
4. Test CallMeBot directly: Visit https://api.callmebot.com/signal/send.php?phone=YOUR_PHONE&apikey=YOUR_KEY&text=Test

### Service not starting?
1. Check docker compose config: `docker compose config`
2. Verify network connectivity between services
3. Check logs: `docker compose logs signal-webhook-bridge`

## Validation Results

✅ All 11 integration tests passing
✅ All 14 deployment readiness checks passing
✅ Python syntax validated
✅ YAML syntax validated
✅ Docker compose configurations validated

## Next Steps

After deployment, monitor:
1. Signal bridge health endpoint
2. Alertmanager for alert delivery
3. Docker logs for any errors
4. Signal app for notifications

For issues or questions, refer to `QA_TEST_RESULTS.md` for detailed test information.
