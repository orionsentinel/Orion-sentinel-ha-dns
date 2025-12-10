# Automatic Deployment Feature - User Guide

## Overview

The installation process now includes **automatic deployment** - no more copying and pasting commands! The system automatically creates Docker networks and starts containers for you.

## What Changed

### Before (Old Behavior)
❌ **Manual Command Copying Required:**
1. Complete configuration wizard
2. See list of commands to run
3. Copy commands one by one
4. Paste into terminal
5. Execute each command manually
6. Hope nothing goes wrong

**Problems:**
- Easy to make typos when copying
- Commands might fail without clear errors
- Users had to understand Docker commands
- "Hiccups" and frustration

### After (New Behavior)
✅ **Automatic One-Click Deployment:**
1. Complete configuration wizard
2. Click "Deploy Now" button (Web UI) or answer "Yes" (terminal)
3. System automatically:
   - Creates Docker networks
   - Deploys containers
   - Shows progress in real-time
   - Reports success or failure with logs
4. Done! Access your services immediately

**Benefits:**
- Zero manual commands
- No copying/pasting errors
- Real-time progress feedback
- Clear error messages with logs
- Smooth, professional experience

## How to Use

### Option 1: Web UI (Recommended) 🌐

1. **Start the Web UI:**
   ```bash
   cd rpi-ha-dns-stack
   bash scripts/launch-setup-ui.sh
   ```

2. **Open your browser:**
   - `http://localhost:5555` (on the Pi)
   - `http://<pi-ip>:5555` (from another device)

3. **Complete the 8-step wizard:**
   - Step 1: Prerequisites check
   - Step 2: Hardware survey
   - Step 3: Choose deployment option
   - Step 4: Node role (multi-Pi setups)
   - Step 5: Network configuration
   - Step 6: Security passwords
   - Step 7: Signal notifications (optional)
   - Step 8: Summary and deploy

4. **Click "Generate Configuration"** - creates .env file

5. **Click "Deploy Now" button** 🚀
   - Shows deployment progress with spinner
   - Automatically creates Docker networks
   - Automatically starts containers
   - Shows real-time logs
   - Reports success or errors

6. **Access your services:**
   - Links appear automatically
   - Click to open Pi-hole, Grafana, etc.

### Option 2: Terminal Setup 💻

1. **Run the interactive setup:**
   ```bash
   cd rpi-ha-dns-stack
   bash scripts/interactive-setup.sh
   ```

2. **Answer the configuration questions:**
   - Number of Raspberry Pis
   - RAM amount
   - Deployment option
   - Network settings
   - Passwords

3. **When asked "Deploy automatically now?"**
   - Press `Y` (or just Enter) for automatic deployment
   - Press `N` if you want to deploy manually later

4. **Automatic deployment starts:**
   ```
   ═══ Automatic Deployment ═══
   Creating Docker network...
   ✓ Docker network created successfully
   Deploying stack with docker compose...
   ✓ Deployment successful!
   ```

5. **Access your services** - URLs are shown at the end

### Option 3: Guided Terminal Setup 📝

The simpler `setup.sh` also supports automatic deployment:

```bash
cd rpi-ha-dns-stack
bash scripts/setup.sh
```

This already had automatic deployment - it calls `scripts/install.sh` which executes the deployment automatically.

## Features

### Real-Time Progress
- See what's happening as it happens
- Spinner animation during deployment
- Status updates at each step

### Comprehensive Error Handling
- Clear error messages if something fails
- Full deployment logs available
- Suggestions for fixing issues
- Option to retry or use manual deployment

### Manual Option Still Available
- Automatic deployment is optional
- Can still get manual commands if preferred
- Useful for advanced users or troubleshooting
- "Details" section shows manual instructions

### Multi-Pi Support
- For 2-Pi setups, deploys the first node automatically
- Shows clear instructions for second node
- Explains sync configuration
- Handles primary/secondary roles correctly

## Technical Details

### What Happens During Automatic Deployment

1. **Network Creation:**
   ```bash
   docker network create -d macvlan \
     --subnet=<your-subnet> \
     --gateway=<your-gateway> \
     -o parent=<your-interface> dns_net
   ```

2. **Container Deployment:**
   ```bash
   cd <deployment-directory>
   docker compose up -d
   ```

3. **Status Check:**
   ```bash
   docker compose ps
   ```

### For Multi-Pi Setups

**Primary Node (Node 1):**
- Automatically deployed when you run the wizard
- Creates network and starts containers
- Configured as MASTER for keepalived

**Secondary Node (Node 2):**
- Must be deployed on the second Raspberry Pi
- Clear instructions provided after primary deployment
- Can also use automatic deployment on second Pi
- Configured as BACKUP for keepalived

## Error Handling

### If Deployment Fails

The system will:
1. Show the error message clearly
2. Display full deployment logs
3. Keep the "Deploy Now" button available
4. Provide manual deployment instructions as fallback

### Common Issues and Solutions

**Issue: "Failed to create Docker network"**
- **Cause:** Network interface doesn't exist or wrong name
- **Solution:** Check your network interface name with `ip link show`
- **Fix:** Update `.env` file with correct `NETWORK_INTERFACE`

**Issue: "Docker Compose deployment failed"**
- **Cause:** Docker daemon not running or permission issues
- **Solution:** 
  ```bash
  sudo systemctl start docker
  sudo usermod -aG docker $USER
  newgrp docker
  ```

**Issue: "Deployment timed out"**
- **Cause:** Slow network or large image downloads
- **Solution:** Wait and try again, or use manual deployment

### Deployment Logs

Both Web UI and terminal setup show deployment logs:
- Network creation status
- Docker Compose output
- Container startup messages
- Any errors or warnings

In Web UI, logs are in an expandable "View Deployment Logs" section.

## Comparison: Before vs After

| Aspect | Before (Manual) | After (Automatic) |
|--------|-----------------|-------------------|
| **Steps** | 10+ manual commands | 1 button click |
| **Time** | 5-10 minutes | 2-3 minutes |
| **Errors** | Easy to make typos | Zero typos |
| **Feedback** | Run each command separately | Real-time progress |
| **Logs** | Must check manually | Shown automatically |
| **Recovery** | Start over if error | Clear error + retry option |
| **Experience** | Frustrating "hiccups" | Smooth and professional |

## Multi-Language Support

The automatic deployment works for:
- Single Pi setups (`HighAvail_1Pi2P2U`)
- Two-Pi simplified (`HighAvail_2Pi1P1U`) ⭐ Recommended
- Two-Pi full redundancy (`HighAvail_2Pi2P2U`)

## Safety Features

### Safe Defaults
- Always asks before deploying
- Shows summary before execution
- Manual option always available

### Graceful Failure
- Doesn't crash on errors
- Shows detailed error information
- Allows retry or manual deployment

### Permission Handling
- Checks Docker permissions
- Provides clear instructions if lacking
- Doesn't require root

## Examples

### Example 1: Successful Web UI Deployment

```
✓ Configuration Generated Successfully!

Ready to Deploy?
[Deploy Now Button Clicked]

Deployment in Progress...
⏳ Starting deployment...

✓ Deployment Successful!

🎉 Access Your Services:
• Pi-hole Primary: http://192.168.8.251/admin
• Pi-hole Secondary: http://192.168.8.252/admin
• Grafana: http://192.168.8.250:3000
```

### Example 2: Successful Terminal Deployment

```
═══ Configuration Complete! ═══

Would you like to deploy automatically now? (Y/n): y

═══ Automatic Deployment ═══
Creating Docker network...
✓ Docker network created successfully

Deploying stack with docker compose...
[+] Running 6/6
 ✔ Container pihole_primary     Started
 ✔ Container pihole_secondary   Started
 ✔ Container unbound_primary    Started
 ✔ Container unbound_secondary  Started
 ✔ Container keepalived         Started
 ✔ Container pihole_sync        Started

✓ Deployment successful!

Access your services at:
• Pi-hole Primary:   http://192.168.8.251/admin
• Pi-hole Secondary: http://192.168.8.252/admin
• Grafana:           http://192.168.8.250:3000

Setup wizard complete! 🎉
```

## FAQ

**Q: Is automatic deployment safe?**
A: Yes! It runs the same commands you would run manually. The code is open source and reviewed.

**Q: What if I prefer manual deployment?**
A: No problem! Click "Manual Deployment Instructions" or answer "No" when asked. You'll get the exact commands to run.

**Q: Can I see what commands are being run?**
A: Yes! The deployment logs show exactly what's being executed. In the Web UI, click "View Deployment Logs".

**Q: What if deployment fails?**
A: You'll see the error message and logs. The "Deploy Now" button stays available to retry, or you can use manual deployment.

**Q: Does this work for 2-Pi setups?**
A: Yes! It deploys the primary node automatically. You then run the same wizard on the second Pi for the secondary node.

**Q: Can I still use the old install.sh script?**
A: Yes! The `scripts/install.sh` script still works exactly as before for manual deployment.

**Q: Is this faster than manual deployment?**
A: Yes! Automatic deployment is 2-3x faster because there's no typing or copying commands.

## Conclusion

The new automatic deployment feature eliminates the "hiccups" and frustration of manual command copying. It provides a smooth, professional installation experience while still maintaining the flexibility of manual deployment for advanced users.

**Result:** Installation is now as easy as clicking a button! 🚀

---

**Need Help?**
- See [TROUBLESHOOTING.md](TROUBLESHOOTING.md) for common issues
- See [GETTING_STARTED.md](GETTING_STARTED.md) for quick reference
- Create an issue on GitHub for support
