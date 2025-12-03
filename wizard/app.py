#!/usr/bin/env python3
"""
First-Run Web Wizard for Orion Sentinel DNS HA

This minimal web application provides a guided setup experience for
non-expert users to configure DNS HA without editing YAML files.

Features:
- Welcome screen with introduction
- Network configuration (single-node vs HA mode)
- DNS profile selection (Family / Standard / Paranoid)
- Completion screen with next steps

Built with Flask and Jinja2 templates for simplicity.
"""

from flask import Flask, render_template, request, jsonify, redirect, url_for
import os
import sys
import subprocess
import re
from pathlib import Path
from typing import Dict, Optional
import bcrypt  # For secure password hashing

app = Flask(__name__)
app.secret_key = os.urandom(24)

# Constants
VALID_NODE_ROLES = ['primary', 'secondary']
PRIMARY_ROLE = 'primary'
SECONDARY_ROLE = 'secondary'
VALID_DEPLOYMENT_MODES = ['single', 'ha']

# Paths
REPO_ROOT = Path(__file__).parent.parent.absolute()
ENV_FILE = REPO_ROOT / "stacks" / "dns" / ".env"
ENV_EXAMPLE = REPO_ROOT / "stacks" / "dns" / "env.example"
SETUP_DONE_FILE = REPO_ROOT / "wizard" / ".setup_done"
PROFILES_DIR = REPO_ROOT / "profiles"
APPLY_PROFILE_SCRIPT = REPO_ROOT / "scripts" / "apply-profile.py"


def is_setup_done() -> bool:
    """Check if initial setup has been completed."""
    return SETUP_DONE_FILE.exists()


def mark_setup_done():
    """Mark setup as completed."""
    SETUP_DONE_FILE.touch()
    with open(SETUP_DONE_FILE, 'w') as f:
        f.write("Setup completed\n")


def detect_pi_ip() -> str:
    """Detect the Pi's primary IP address."""
    try:
        result = subprocess.run(
            ['hostname', '-I'],
            capture_output=True,
            text=True,
            timeout=5
        )
        if result.returncode == 0:
            ips = result.stdout.strip().split()
            if ips:
                return ips[0]  # Return first IP
    except Exception:
        pass
    return "192.168.1.100"  # Fallback default


def detect_interface() -> str:
    """Detect the primary network interface."""
    try:
        result = subprocess.run(
            ['ip', 'route', 'show', 'default'],
            capture_output=True,
            text=True,
            timeout=5
        )
        if result.returncode == 0:
            # Parse: default via 192.168.1.1 dev eth0 proto dhcp src 192.168.1.100 metric 100
            match = re.search(r'dev\s+(\S+)', result.stdout)
            if match:
                return match.group(1)
    except Exception:
        pass
    return "eth0"  # Fallback default


def update_env_file(config: Dict[str, str]) -> bool:
    """
    Update .env file with configuration values.
    
    Args:
        config: Dictionary of configuration key-value pairs
        
    Returns:
        True if successful, False otherwise
    """
    try:
        # Read .env.example as template if .env doesn't exist
        if not ENV_FILE.exists() and ENV_EXAMPLE.exists():
            with open(ENV_EXAMPLE, 'r') as f:
                env_content = f.read()
        elif ENV_FILE.exists():
            with open(ENV_FILE, 'r') as f:
                env_content = f.read()
        else:
            # Create minimal .env if neither exists
            env_content = ""
        
        # Update or add each configuration value
        for key, value in config.items():
            # Escape special characters in value
            safe_value = str(value).replace('"', '\\"')
            
            # Check if key exists in content
            pattern = re.compile(rf'^{re.escape(key)}=.*$', re.MULTILINE)
            if pattern.search(env_content):
                # Replace existing value
                env_content = pattern.sub(f'{key}="{safe_value}"', env_content)
            else:
                # Add new key=value
                env_content += f'\n{key}="{safe_value}"'
        
        # Write updated content
        ENV_FILE.parent.mkdir(parents=True, exist_ok=True)
        with open(ENV_FILE, 'w') as f:
            f.write(env_content)
        
        return True
    except Exception as e:
        print(f"Error updating .env file: {e}", file=sys.stderr)
        return False


@app.route('/')
def index():
    """Main router - redirect to welcome or setup_complete based on status."""
    if is_setup_done():
        return redirect(url_for('setup_complete'))
    return redirect(url_for('welcome'))


@app.route('/welcome')
def welcome():
    """Welcome page - introduction to Orion DNS HA."""
    if is_setup_done():
        return redirect(url_for('setup_complete'))
    return render_template('welcome.html')


@app.route('/network')
def network():
    """Network configuration page."""
    if is_setup_done():
        return redirect(url_for('setup_complete'))
    
    # Detect system info
    detected_ip = detect_pi_ip()
    detected_interface = detect_interface()
    
    return render_template(
        'network.html',
        detected_ip=detected_ip,
        detected_interface=detected_interface
    )


@app.route('/api/network', methods=['POST'])
def api_network():
    """API endpoint to save network configuration."""
    try:
        data = request.get_json()
        
        # Validate input
        mode = data.get('mode')
        if mode not in VALID_DEPLOYMENT_MODES:
            return jsonify({'success': False, 'error': 'Invalid mode'}), 400
        
        pi_ip = data.get('pi_ip', '').strip()
        if not pi_ip:
            return jsonify({'success': False, 'error': 'Pi IP is required'}), 400
        
        interface = data.get('interface', '').strip()
        if not interface:
            return jsonify({'success': False, 'error': 'Network interface is required'}), 400
        
        pihole_password = data.get('pihole_password', '').strip()
        if not pihole_password or len(pihole_password) < 8:
            return jsonify({'success': False, 'error': 'Pi-hole password must be at least 8 characters'}), 400
        
        # Build configuration
        config = {
            'HOST_IP': pi_ip,
            'NETWORK_INTERFACE': interface,
            'PIHOLE_PASSWORD': pihole_password
        }
        
        if mode == 'single':
            # Single-node: VIP = Pi IP, single-pi-ha profile
            config['DEPLOYMENT_MODE'] = 'single-pi-ha'
            config['VIP_ADDRESS'] = pi_ip
            config['NODE_ROLE'] = PRIMARY_ROLE
            config['KEEPALIVED_PRIORITY'] = '100'
        else:
            # Two-Pi HA mode
            vip = data.get('vip', '').strip()
            if not vip:
                return jsonify({'success': False, 'error': 'VIP is required for Two-Pi HA mode'}), 400
            
            peer_ip = data.get('peer_ip', '').strip()
            if not peer_ip:
                return jsonify({'success': False, 'error': 'Peer IP is required for Two-Pi HA mode'}), 400
            
            node_role = data.get('node_role', '').strip().lower()
            if node_role not in VALID_NODE_ROLES:
                return jsonify({'success': False, 'error': 'Invalid node role'}), 400
            
            vrrp_password = data.get('vrrp_password', '').strip()
            if not vrrp_password or len(vrrp_password) < 8:
                return jsonify({'success': False, 'error': 'VRRP password must be at least 8 characters'}), 400
            
            # Two-Pi HA configuration
            config['DEPLOYMENT_MODE'] = 'two-pi-ha'
            config['VIP_ADDRESS'] = vip
            config['PEER_IP'] = peer_ip
            config['NODE_ROLE'] = node_role
            config['VRRP_PASSWORD'] = vrrp_password
            
            # Set priority based on role
            if node_role == PRIMARY_ROLE:
                config['KEEPALIVED_PRIORITY'] = '200'
                config['NODE_HOSTNAME'] = 'pi1-dns'
            else:  # SECONDARY_ROLE
                config['KEEPALIVED_PRIORITY'] = '150'
                config['NODE_HOSTNAME'] = 'pi2-dns'
        
        # Update .env file
        if not update_env_file(config):
            return jsonify({'success': False, 'error': 'Failed to update configuration file'}), 500
        
        return jsonify({'success': True})
    
    except Exception as e:
        print(f"Error in api_network: {e}", file=sys.stderr)
        return jsonify({'success': False, 'error': 'Internal server error'}), 500


@app.route('/profile')
def profile():
    """DNS profile selection page."""
    if is_setup_done():
        return redirect(url_for('setup_complete'))
    
    # Load profile information
    profiles = []
    for profile_file in ['standard.yml', 'family.yml', 'paranoid.yml']:
        profile_path = PROFILES_DIR / profile_file
        if profile_path.exists():
            # Read basic info from YAML (simple parsing)
            try:
                import yaml
                with open(profile_path, 'r') as f:
                    profile_data = yaml.safe_load(f)
                    profiles.append({
                        'id': profile_file.replace('.yml', ''),
                        'name': profile_data.get('name', '').title(),
                        'description': profile_data.get('description', '')
                    })
            except Exception:
                # Fallback if YAML parsing fails
                profiles.append({
                    'id': profile_file.replace('.yml', ''),
                    'name': profile_file.replace('.yml', '').title(),
                    'description': ''
                })
    
    return render_template('profile.html', profiles=profiles)


@app.route('/api/profile', methods=['POST'])
def api_profile():
    """API endpoint to apply selected DNS profile."""
    try:
        data = request.get_json()
        profile_id = data.get('profile')
        
        if not profile_id:
            return jsonify({'success': False, 'error': 'Profile ID is required'}), 400
        
        if profile_id not in ['standard', 'family', 'paranoid']:
            return jsonify({'success': False, 'error': 'Invalid profile'}), 400
        
        # Store profile selection in config
        profile_config = {'DNS_PROFILE': profile_id}
        if not update_env_file(profile_config):
            return jsonify({'success': False, 'error': 'Failed to save profile selection'}), 500
        
        # Apply profile using apply-profile.py script
        # Note: This will run after docker compose up, so we just save the selection
        # The actual application can be done by the user or as part of first boot
        
        # Mark setup as done
        mark_setup_done()
        
        return jsonify({'success': True})
    
    except Exception as e:
        print(f"Error in api_profile: {e}", file=sys.stderr)
        return jsonify({'success': False, 'error': 'Internal server error'}), 500


@app.route('/done')
def setup_complete():
    """Setup completion page with next steps."""
    # Read configuration to show user
    config = {}
    if ENV_FILE.exists():
        try:
            with open(ENV_FILE, 'r') as f:
                for line in f:
                    line = line.strip()
                    if '=' in line and not line.startswith('#'):
                        key, value = line.split('=', 1)
                        config[key] = value.strip('"').strip("'")
        except Exception:
            pass
    
    dns_ip = config.get('DNS_VIP', config.get('VIP_ADDRESS', 'your-dns-ip'))
    pihole_ip = config.get('PRIMARY_DNS_IP', dns_ip)
    
    return render_template(
        'done.html',
        dns_ip=dns_ip,
        pihole_ip=pihole_ip,
        already_setup=is_setup_done()
    )


@app.route('/api/reapply-profile', methods=['POST'])
def api_reapply_profile():
    """API endpoint to re-apply a profile after setup is complete."""
    try:
        data = request.get_json()
        profile_id = data.get('profile')
        
        if not profile_id:
            return jsonify({'success': False, 'error': 'Profile ID is required'}), 400
        
        if profile_id not in ['standard', 'family', 'paranoid']:
            return jsonify({'success': False, 'error': 'Invalid profile'}), 400
        
        # Update profile in config
        profile_config = {'DNS_PROFILE': profile_id}
        if not update_env_file(profile_config):
            return jsonify({'success': False, 'error': 'Failed to save profile selection'}), 500
        
        return jsonify({'success': True, 'message': f'Profile "{profile_id}" saved. Apply it by running: python3 scripts/apply-profile.py --profile {profile_id}'})
    
    except Exception as e:
        print(f"Error in api_reapply_profile: {e}", file=sys.stderr)
        return jsonify({'success': False, 'error': 'Internal server error'}), 500


if __name__ == '__main__':
    # Run on all interfaces, port 8080 (as specified in requirements)
    app.run(host='0.0.0.0', port=8080, debug=False)
