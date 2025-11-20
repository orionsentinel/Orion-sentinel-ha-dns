#!/usr/bin/env python3
"""
First-Run Web Wizard for Orion Sentinel DNS HA

A minimal Flask-based web application for guiding users through
initial setup of the DNS HA stack.

Usage:
    python3 wizard/app.py

Then visit: http://<pi-ip>:8080
"""

import os
import sys
import re
from pathlib import Path
from flask import Flask, render_template, request, jsonify, redirect, url_for
import subprocess
import socket

app = Flask(__name__)
app.secret_key = os.urandom(24)

# Paths
REPO_ROOT = Path(__file__).parent.parent.absolute()
ENV_FILE = REPO_ROOT / '.env'
ENV_EXAMPLE = REPO_ROOT / '.env.example'
SETUP_SENTINEL = REPO_ROOT / 'wizard' / '.setup_done'
CONFIG_DIR = REPO_ROOT / 'config'
PROFILES_DIR = CONFIG_DIR / 'profiles'

# Ensure config/profiles directory exists (symlink to /profiles if needed)
if not PROFILES_DIR.exists():
    CONFIG_DIR.mkdir(exist_ok=True)
    # Check if /profiles exists at repo root
    root_profiles = REPO_ROOT / 'profiles'
    if root_profiles.exists():
        # Create symlink
        PROFILES_DIR.symlink_to(root_profiles)
    else:
        # Create directory
        PROFILES_DIR.mkdir(exist_ok=True)


def is_setup_done():
    """Check if first-run setup has been completed"""
    return SETUP_SENTINEL.exists()


def mark_setup_done():
    """Mark setup as completed"""
    SETUP_SENTINEL.touch()


def get_default_ip():
    """Get default IP address of the Pi"""
    try:
        # Get IP from hostname -I
        result = subprocess.run(
            ['hostname', '-I'],
            capture_output=True,
            text=True,
            check=True
        )
        ips = result.stdout.strip().split()
        if ips:
            return ips[0]
    except Exception:
        pass
    
    # Fallback: try socket method
    try:
        s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        s.connect(('8.8.8.8', 80))
        ip = s.getsockname()[0]
        s.close()
        return ip
    except Exception:
        pass
    
    return '192.168.8.250'


def get_default_interface():
    """Get default network interface"""
    try:
        # Get default route interface
        result = subprocess.run(
            ['ip', 'route', 'show', 'default'],
            capture_output=True,
            text=True,
            check=True
        )
        # Parse: "default via 192.168.8.1 dev eth0 ..."
        match = re.search(r'dev\s+(\S+)', result.stdout)
        if match:
            return match.group(1)
    except Exception:
        pass
    
    return 'eth0'


def update_env_file(config):
    """Update .env file with configuration"""
    # Read existing .env or .env.example
    if ENV_FILE.exists():
        env_path = ENV_FILE
    elif ENV_EXAMPLE.exists():
        env_path = ENV_EXAMPLE
    else:
        raise FileNotFoundError("No .env or .env.example found")
    
    with open(env_path, 'r') as f:
        lines = f.readlines()
    
    # Update values
    updated_lines = []
    for line in lines:
        # Skip empty lines and comments
        if not line.strip() or line.strip().startswith('#'):
            updated_lines.append(line)
            continue
        
        # Parse KEY=VALUE
        if '=' in line:
            key = line.split('=')[0].strip()
            
            # Update known keys
            if key == 'HOST_IP' and 'pi_ip' in config:
                updated_lines.append(f"HOST_IP={config['pi_ip']}\n")
            elif key == 'VIP_ADDRESS' and 'vip' in config:
                updated_lines.append(f"VIP_ADDRESS={config['vip']}\n")
            elif key == 'NETWORK_INTERFACE' and 'interface' in config:
                updated_lines.append(f"NETWORK_INTERFACE={config['interface']}\n")
            elif key == 'PIHOLE_PASSWORD' and 'pihole_password' in config:
                updated_lines.append(f"PIHOLE_PASSWORD={config['pihole_password']}\n")
            elif key == 'WEBPASSWORD' and 'pihole_password' in config:
                updated_lines.append(f"WEBPASSWORD={config['pihole_password']}\n")
            elif key == 'NODE_ROLE' and 'node_role' in config:
                updated_lines.append(f"NODE_ROLE={config['node_role']}\n")
            else:
                updated_lines.append(line)
        else:
            updated_lines.append(line)
    
    # Write updated .env
    with open(ENV_FILE, 'w') as f:
        f.writelines(updated_lines)


def apply_profile(profile_name):
    """
    Apply DNS security profile using apply-profile.py script
    
    Args:
        profile_name: Name of profile (standard, family, paranoid)
    
    Returns:
        dict with success status and message
    """
    apply_script = REPO_ROOT / 'scripts' / 'apply-profile.py'
    
    if not apply_script.exists():
        return {'success': False, 'error': 'apply-profile.py script not found'}
    
    try:
        # Run apply-profile.py with the selected profile
        result = subprocess.run(
            ['python3', str(apply_script), '--profile', profile_name],
            capture_output=True,
            text=True,
            timeout=60
        )
        
        if result.returncode == 0:
            return {'success': True, 'message': f'Profile {profile_name} applied successfully'}
        else:
            return {'success': False, 'error': result.stderr or result.stdout}
    
    except subprocess.TimeoutExpired:
        return {'success': False, 'error': 'Profile application timed out'}
    except Exception as e:
        return {'success': False, 'error': str(e)}


@app.route('/')
def index():
    """Main landing page"""
    if is_setup_done():
        return render_template('setup_complete.html')
    return render_template('welcome.html')


@app.route('/network')
def network():
    """Network configuration page"""
    if is_setup_done():
        return redirect(url_for('index'))
    
    # Detect defaults
    default_ip = get_default_ip()
    default_interface = get_default_interface()
    
    return render_template(
        'network_config.html',
        default_ip=default_ip,
        default_interface=default_interface
    )


@app.route('/api/network', methods=['POST'])
def save_network():
    """Save network configuration"""
    try:
        data = request.json
        
        # Validate required fields
        required = ['mode', 'pi_ip', 'interface', 'pihole_password']
        for field in required:
            if field not in data or not data[field]:
                return jsonify({'success': False, 'error': f'Missing required field: {field}'}), 400
        
        # Build config
        config = {
            'pi_ip': data['pi_ip'],
            'interface': data['interface'],
            'pihole_password': data['pihole_password']
        }
        
        # Handle mode-specific config
        if data['mode'] == 'single':
            # Single-node: VIP = Pi IP
            config['vip'] = data['pi_ip']
            config['node_role'] = 'MASTER'
        elif data['mode'] == 'ha':
            # HA mode: separate VIP and node role
            if 'vip' not in data or not data['vip']:
                return jsonify({'success': False, 'error': 'VIP required for HA mode'}), 400
            if 'node_role' not in data or data['node_role'] not in ['MASTER', 'BACKUP']:
                return jsonify({'success': False, 'error': 'Invalid node role'}), 400
            
            config['vip'] = data['vip']
            config['node_role'] = data['node_role']
        else:
            return jsonify({'success': False, 'error': 'Invalid mode'}), 400
        
        # Update .env file
        update_env_file(config)
        
        return jsonify({'success': True})
    
    except Exception as e:
        return jsonify({'success': False, 'error': str(e)}), 500


@app.route('/profile')
def profile():
    """DNS profile selection page"""
    if is_setup_done():
        return redirect(url_for('index'))
    
    # Check if network config is done
    if not ENV_FILE.exists():
        return redirect(url_for('network'))
    
    return render_template('profile_selection.html')


@app.route('/api/profile', methods=['POST'])
def save_profile():
    """Save and apply DNS profile"""
    try:
        data = request.json
        
        if 'profile' not in data:
            return jsonify({'success': False, 'error': 'No profile selected'}), 400
        
        profile_name = data['profile']
        
        # Validate profile
        valid_profiles = ['standard', 'family', 'paranoid']
        if profile_name not in valid_profiles:
            return jsonify({'success': False, 'error': 'Invalid profile'}), 400
        
        # Note: We'll apply the profile after stack is deployed
        # For now, just save the selection
        profile_file = REPO_ROOT / 'wizard' / '.selected_profile'
        profile_file.write_text(profile_name)
        
        # Mark setup as done
        mark_setup_done()
        
        return jsonify({'success': True, 'profile': profile_name})
    
    except Exception as e:
        return jsonify({'success': False, 'error': str(e)}), 500


@app.route('/done')
def done():
    """Setup complete page"""
    if not is_setup_done():
        return redirect(url_for('index'))
    
    # Get configuration details
    pi_ip = get_default_ip()
    vip = pi_ip  # Default, will be overridden if found in .env
    
    # Try to read VIP from .env
    if ENV_FILE.exists():
        with open(ENV_FILE, 'r') as f:
            for line in f:
                if line.startswith('VIP_ADDRESS='):
                    vip = line.split('=')[1].strip()
                    break
    
    return render_template('setup_complete.html', pi_ip=pi_ip, vip=vip)


@app.route('/health')
def health():
    """Health check endpoint"""
    return jsonify({'status': 'ok', 'setup_done': is_setup_done()})


if __name__ == '__main__':
    # Run on all interfaces, port 8080
    print(f"Starting Orion Sentinel DNS HA First-Run Wizard...")
    print(f"Repository root: {REPO_ROOT}")
    print(f"Setup completed: {is_setup_done()}")
    print(f"\nAccess the wizard at: http://<your-pi-ip>:8080")
    print(f"Or from the Pi: http://localhost:8080")
    
    app.run(host='0.0.0.0', port=8080, debug=False)
