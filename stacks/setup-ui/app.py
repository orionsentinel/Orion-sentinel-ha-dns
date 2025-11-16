#!/usr/bin/env python3
"""
Web-based Setup UI for RPi HA DNS Stack
Provides a graphical interface for installation and configuration
"""
from flask import Flask, render_template, request, jsonify, session, send_from_directory
import os
import subprocess
import json
import re
import secrets
from pathlib import Path
from datetime import timedelta

app = Flask(__name__)
app.secret_key = secrets.token_hex(32)
app.config['SESSION_TYPE'] = 'filesystem'
app.config['PERMANENT_SESSION_LIFETIME'] = timedelta(hours=2)

REPO_ROOT = Path(__file__).parent.parent.parent.absolute()
ENV_FILE = REPO_ROOT / '.env'
ENV_EXAMPLE = REPO_ROOT / '.env.example'

# Default configuration values
DEFAULT_CONFIG = {
    'HOST_IP': '192.168.8.250',
    'PRIMARY_DNS_IP': '192.168.8.251',
    'SECONDARY_DNS_IP': '192.168.8.252',
    'PRIMARY_UNBOUND_IP': '192.168.8.253',
    'SECONDARY_UNBOUND_IP': '192.168.8.254',
    'VIP_ADDRESS': '192.168.8.255',
    'NETWORK_INTERFACE': 'eth0',
    'SUBNET': '192.168.8.0/24',
    'GATEWAY': '192.168.8.1',
    'DEPLOYMENT_OPTION': 'HighAvail_2Pi1P1U',
    'NODE_ROLE': 'primary',  # primary or secondary
    'PRIMARY_NODE_IP': '',  # Only needed when NODE_ROLE is secondary
}

@app.route('/')
def index():
    """Main page - setup wizard landing"""
    return render_template('index.html')

@app.route('/api/prerequisites', methods=['GET'])
def check_prerequisites():
    """Check system prerequisites"""
    checks = {
        'docker': check_docker(),
        'docker_compose': check_docker_compose(),
        'git': check_git(),
        'disk_space': check_disk_space(),
        'memory': check_memory(),
        'network_tools': check_network_tools(),
    }
    
    all_passed = all(check['status'] for check in checks.values())
    
    return jsonify({
        'success': all_passed,
        'checks': checks
    })

@app.route('/api/hardware-survey', methods=['GET'])
def hardware_survey():
    """Survey system hardware"""
    return jsonify({
        'cpu': get_cpu_info(),
        'memory': get_memory_info(),
        'disk': get_disk_info(),
        'network': get_network_interfaces(),
    })

@app.route('/api/network-config', methods=['GET', 'POST'])
def network_config():
    """Get or save network configuration"""
    if request.method == 'POST':
        config = request.json
        session['network_config'] = config
        
        # Validate configuration
        validation = validate_network_config(config)
        if not validation['valid']:
            return jsonify({'success': False, 'errors': validation['errors']}), 400
        
        return jsonify({'success': True})
    
    # GET request - return current or default config
    return jsonify(session.get('network_config', DEFAULT_CONFIG))

@app.route('/api/security-config', methods=['GET', 'POST'])
def security_config():
    """Get or save security configuration"""
    if request.method == 'POST':
        config = request.json
        
        # Validate passwords
        if config.get('pihole_password') != config.get('pihole_password_confirm'):
            return jsonify({'success': False, 'error': 'Pi-hole passwords do not match'}), 400
        
        if config.get('grafana_password') != config.get('grafana_password_confirm'):
            return jsonify({'success': False, 'error': 'Grafana passwords do not match'}), 400
        
        # Store in session (don't log passwords)
        session['security_config'] = {
            'pihole_password': config.get('pihole_password'),
            'grafana_password': config.get('grafana_password'),
        }
        
        return jsonify({'success': True})
    
    # GET request - return empty config (don't send passwords)
    return jsonify({
        'pihole_password': '',
        'grafana_password': '',
    })

@app.route('/api/signal-config', methods=['GET', 'POST'])
def signal_config():
    """Get or save Signal notification configuration"""
    if request.method == 'POST':
        config = request.json
        session['signal_config'] = config
        return jsonify({'success': True})
    
    return jsonify(session.get('signal_config', {
        'enabled': False,
        'signal_number': '',
        'signal_recipients': '',
    }))

@app.route('/api/deployment-option', methods=['GET', 'POST'])
def deployment_option():
    """Get or save deployment option"""
    if request.method == 'POST':
        config = request.json
        session['deployment_option'] = config.get('option')
        return jsonify({'success': True})
    
    return jsonify({
        'option': session.get('deployment_option', 'HighAvail_2Pi1P1U')
    })

@app.route('/api/node-role', methods=['GET', 'POST'])
def node_role():
    """Get or save node role configuration for multi-Pi deployments"""
    if request.method == 'POST':
        config = request.json
        
        # Validate node role
        if config.get('node_role') not in ['primary', 'secondary']:
            return jsonify({'success': False, 'error': 'Invalid node role'}), 400
        
        # If secondary, validate primary node IP
        if config.get('node_role') == 'secondary':
            primary_ip = config.get('primary_node_ip', '').strip()
            if not primary_ip:
                return jsonify({'success': False, 'error': 'Primary node IP is required for secondary nodes'}), 400
            if not is_valid_ip(primary_ip):
                return jsonify({'success': False, 'error': 'Primary node IP is not a valid IP address'}), 400
        
        session['node_role_config'] = {
            'node_role': config.get('node_role'),
            'primary_node_ip': config.get('primary_node_ip', '').strip() if config.get('node_role') == 'secondary' else ''
        }
        
        return jsonify({'success': True})
    
    return jsonify(session.get('node_role_config', {
        'node_role': 'primary',
        'primary_node_ip': ''
    }))

@app.route('/api/generate-config', methods=['POST'])
def generate_config():
    """Generate .env file from collected configuration"""
    try:
        network = session.get('network_config', DEFAULT_CONFIG)
        security = session.get('security_config', {})
        signal = session.get('signal_config', {})
        deployment = session.get('deployment_option', 'HighAvail_2Pi1P1U')
        node_role_config = session.get('node_role_config', {'node_role': 'primary', 'primary_node_ip': ''})
        
        # Read example env file
        if not ENV_EXAMPLE.exists():
            return jsonify({'success': False, 'error': '.env.example not found'}), 500
        
        env_content = ENV_EXAMPLE.read_text()
        
        # Replace values
        replacements = {
            'HOST_IP': network.get('HOST_IP'),
            'PRIMARY_DNS_IP': network.get('PRIMARY_DNS_IP'),
            'SECONDARY_DNS_IP': network.get('SECONDARY_DNS_IP'),
            'PRIMARY_UNBOUND_IP': network.get('PRIMARY_UNBOUND_IP'),
            'SECONDARY_UNBOUND_IP': network.get('SECONDARY_UNBOUND_IP'),
            'VIP_ADDRESS': network.get('VIP_ADDRESS'),
            'NETWORK_INTERFACE': network.get('NETWORK_INTERFACE'),
            'SUBNET': network.get('SUBNET'),
            'GATEWAY': network.get('GATEWAY'),
            'WEBPASSWORD': security.get('pihole_password', 'changeme'),
            'GF_SECURITY_ADMIN_PASSWORD': security.get('grafana_password', 'changeme'),
        }
        
        # Add Signal configuration if enabled
        if signal.get('enabled'):
            replacements['SIGNAL_NUMBER'] = signal.get('signal_number', '')
            replacements['SIGNAL_RECIPIENTS'] = signal.get('signal_recipients', '')
        
        # Replace in env content
        for key, value in replacements.items():
            env_content = re.sub(
                f'^{key}=.*$',
                f'{key}={value}',
                env_content,
                flags=re.MULTILINE
            )
        
        # Add node role configuration as comments for multi-Pi setups
        if deployment in ['HighAvail_2Pi1P1U', 'HighAvail_2Pi2P2U']:
            node_role_comment = f"\n# Node Role Configuration\n"
            node_role_comment += f"# NODE_ROLE={node_role_config.get('node_role', 'primary')}\n"
            if node_role_config.get('node_role') == 'secondary' and node_role_config.get('primary_node_ip'):
                node_role_comment += f"# PRIMARY_NODE_IP={node_role_config.get('primary_node_ip')}\n"
            env_content += node_role_comment
        
        # Write .env file
        ENV_FILE.write_text(env_content)
        
        # Determine deployment path based on node role for multi-Pi setups
        deployment_path_suffix = ''
        if deployment in ['HighAvail_2Pi1P1U', 'HighAvail_2Pi2P2U']:
            node_role = node_role_config.get('node_role', 'primary')
            deployment_path_suffix = f'/node1' if node_role == 'primary' else f'/node2'
        
        return jsonify({
            'success': True,
            'deployment_option': deployment,
            'node_role': node_role_config.get('node_role', 'primary'),
            'deployment_path_suffix': deployment_path_suffix,
            'config_path': str(ENV_FILE)
        })
        
    except Exception as e:
        return jsonify({'success': False, 'error': str(e)}), 500

@app.route('/api/deploy', methods=['POST'])
def deploy():
    """Execute deployment"""
    try:
        deployment = session.get('deployment_option', 'HighAvail_2Pi1P1U')
        node_role_config = session.get('node_role_config', {'node_role': 'primary', 'primary_node_ip': ''})
        
        # Store deployment status in session
        session['deployment_status'] = 'starting'
        
        # Get deployment script path
        if deployment == 'HighAvail_1Pi2P2U':
            script_path = REPO_ROOT / 'deployments' / 'HighAvail_1Pi2P2U'
        elif deployment == 'HighAvail_2Pi1P1U':
            base_path = REPO_ROOT / 'deployments' / 'HighAvail_2Pi1P1U'
            # For multi-Pi setups, add node-specific path
            node_role = node_role_config.get('node_role', 'primary')
            script_path = base_path / ('node1' if node_role == 'primary' else 'node2')
        elif deployment == 'HighAvail_2Pi2P2U':
            base_path = REPO_ROOT / 'deployments' / 'HighAvail_2Pi2P2U'
            # For multi-Pi setups, add node-specific path
            node_role = node_role_config.get('node_role', 'primary')
            script_path = base_path / ('node1' if node_role == 'primary' else 'node2')
        else:
            return jsonify({'success': False, 'error': 'Invalid deployment option'}), 400
        
        # Return deployment instructions instead of executing
        # (actual deployment should be done with proper user interaction)
        return jsonify({
            'success': True,
            'message': 'Configuration saved successfully',
            'deployment_path': str(script_path),
            'node_role': node_role_config.get('node_role', 'primary'),
            'next_steps': [
                f'Navigate to: {script_path}',
                'Run: docker compose up -d',
                'Monitor logs: docker compose logs -f',
            ]
        })
        
    except Exception as e:
        return jsonify({'success': False, 'error': str(e)}), 500

@app.route('/api/deployment-status', methods=['GET'])
def deployment_status():
    """Get current deployment status"""
    status = session.get('deployment_status', 'not_started')
    return jsonify({'status': status})

# Helper functions
def check_docker():
    """Check if Docker is installed"""
    try:
        result = subprocess.run(['docker', '--version'], capture_output=True, text=True, timeout=5)
        if result.returncode == 0:
            version = result.stdout.strip()
            return {'status': True, 'message': f'Docker installed: {version}'}
        return {'status': False, 'message': 'Docker not found'}
    except (subprocess.TimeoutExpired, FileNotFoundError):
        return {'status': False, 'message': 'Docker not installed'}

def check_docker_compose():
    """Check if Docker Compose is installed"""
    try:
        result = subprocess.run(['docker', 'compose', 'version'], capture_output=True, text=True, timeout=5)
        if result.returncode == 0:
            version = result.stdout.strip()
            return {'status': True, 'message': f'Docker Compose installed: {version}'}
        return {'status': False, 'message': 'Docker Compose not found'}
    except (subprocess.TimeoutExpired, FileNotFoundError):
        return {'status': False, 'message': 'Docker Compose not installed'}

def check_git():
    """Check if Git is installed"""
    try:
        result = subprocess.run(['git', '--version'], capture_output=True, text=True, timeout=5)
        if result.returncode == 0:
            version = result.stdout.strip()
            return {'status': True, 'message': f'Git installed: {version}'}
        return {'status': False, 'message': 'Git not found'}
    except (subprocess.TimeoutExpired, FileNotFoundError):
        return {'status': False, 'message': 'Git not installed'}

def check_disk_space():
    """Check available disk space"""
    try:
        result = subprocess.run(['df', '-h', '/'], capture_output=True, text=True, timeout=5)
        lines = result.stdout.strip().split('\n')
        if len(lines) > 1:
            parts = lines[1].split()
            available = parts[3]
            usage = parts[4]
            # Check if at least 10GB available
            avail_gb = float(available.replace('G', '').replace('M', '0.')) if 'G' in available or 'M' in available else 0
            if avail_gb >= 10:
                return {'status': True, 'message': f'Disk space: {available} available ({usage} used)'}
            return {'status': False, 'message': f'Low disk space: only {available} available'}
        return {'status': False, 'message': 'Could not check disk space'}
    except (subprocess.TimeoutExpired, FileNotFoundError):
        return {'status': False, 'message': 'Could not check disk space'}

def check_memory():
    """Check available memory"""
    try:
        result = subprocess.run(['free', '-h'], capture_output=True, text=True, timeout=5)
        lines = result.stdout.strip().split('\n')
        if len(lines) > 1:
            parts = lines[1].split()
            total = parts[1]
            available = parts[6] if len(parts) > 6 else parts[3]
            # Check if at least 2GB total
            total_gb = float(total.replace('Gi', '').replace('Mi', '0.')) if 'Gi' in total or 'Mi' in total else 0
            if total_gb >= 2:
                return {'status': True, 'message': f'Memory: {total} total, {available} available'}
            return {'status': False, 'message': f'Low memory: only {total} total'}
        return {'status': False, 'message': 'Could not check memory'}
    except (subprocess.TimeoutExpired, FileNotFoundError):
        return {'status': False, 'message': 'Could not check memory'}

def check_network_tools():
    """Check if network tools are available"""
    try:
        result = subprocess.run(['ip', 'addr'], capture_output=True, text=True, timeout=5)
        if result.returncode == 0:
            return {'status': True, 'message': 'Network tools available'}
        return {'status': False, 'message': 'Network tools not found'}
    except (subprocess.TimeoutExpired, FileNotFoundError):
        return {'status': False, 'message': 'Network tools not installed'}

def get_cpu_info():
    """Get CPU information"""
    try:
        result = subprocess.run(['lscpu'], capture_output=True, text=True, timeout=5)
        if result.returncode == 0:
            lines = result.stdout.strip().split('\n')
            info = {}
            for line in lines:
                if ':' in line:
                    key, value = line.split(':', 1)
                    key = key.strip()
                    value = value.strip()
                    if key in ['Architecture', 'Model name', 'CPU(s)', 'Thread(s) per core', 'Core(s) per socket']:
                        info[key] = value
            return info
        return {'error': 'Could not get CPU info'}
    except (subprocess.TimeoutExpired, FileNotFoundError):
        return {'error': 'lscpu not available'}

def get_memory_info():
    """Get detailed memory information"""
    try:
        result = subprocess.run(['free', '-h'], capture_output=True, text=True, timeout=5)
        if result.returncode == 0:
            lines = result.stdout.strip().split('\n')
            if len(lines) > 1:
                parts = lines[1].split()
                return {
                    'total': parts[1],
                    'used': parts[2],
                    'free': parts[3],
                    'available': parts[6] if len(parts) > 6 else parts[3]
                }
        return {'error': 'Could not get memory info'}
    except (subprocess.TimeoutExpired, FileNotFoundError):
        return {'error': 'free command not available'}

def get_disk_info():
    """Get disk information"""
    try:
        result = subprocess.run(['df', '-h', '/'], capture_output=True, text=True, timeout=5)
        if result.returncode == 0:
            lines = result.stdout.strip().split('\n')
            if len(lines) > 1:
                parts = lines[1].split()
                return {
                    'filesystem': parts[0],
                    'size': parts[1],
                    'used': parts[2],
                    'available': parts[3],
                    'use_percent': parts[4]
                }
        return {'error': 'Could not get disk info'}
    except (subprocess.TimeoutExpired, FileNotFoundError):
        return {'error': 'df command not available'}

def get_network_interfaces():
    """Get network interface information"""
    try:
        result = subprocess.run(['ip', '-br', 'addr'], capture_output=True, text=True, timeout=5)
        if result.returncode == 0:
            interfaces = []
            for line in result.stdout.strip().split('\n'):
                parts = line.split()
                if len(parts) >= 3:
                    interfaces.append({
                        'name': parts[0],
                        'state': parts[1],
                        'addresses': ' '.join(parts[2:])
                    })
            return interfaces
        return []
    except (subprocess.TimeoutExpired, FileNotFoundError):
        return []

def validate_network_config(config):
    """Validate network configuration"""
    errors = []
    
    # Validate IP addresses
    ip_fields = ['HOST_IP', 'PRIMARY_DNS_IP', 'SECONDARY_DNS_IP', 
                 'PRIMARY_UNBOUND_IP', 'SECONDARY_UNBOUND_IP', 'VIP_ADDRESS']
    
    for field in ip_fields:
        if not config.get(field):
            errors.append(f'{field} is required')
        elif not is_valid_ip(config.get(field)):
            errors.append(f'{field} is not a valid IP address')
    
    # Validate subnet
    if not config.get('SUBNET'):
        errors.append('SUBNET is required')
    elif not is_valid_cidr(config.get('SUBNET')):
        errors.append('SUBNET is not a valid CIDR notation')
    
    # Validate gateway
    if not config.get('GATEWAY'):
        errors.append('GATEWAY is required')
    elif not is_valid_ip(config.get('GATEWAY')):
        errors.append('GATEWAY is not a valid IP address')
    
    return {
        'valid': len(errors) == 0,
        'errors': errors
    }

def is_valid_ip(ip):
    """Check if string is a valid IP address"""
    pattern = r'^(\d{1,3}\.){3}\d{1,3}$'
    if not re.match(pattern, ip):
        return False
    parts = ip.split('.')
    return all(0 <= int(part) <= 255 for part in parts)

def is_valid_cidr(cidr):
    """Check if string is valid CIDR notation"""
    pattern = r'^(\d{1,3}\.){3}\d{1,3}/\d{1,2}$'
    if not re.match(pattern, cidr):
        return False
    ip, mask = cidr.split('/')
    return is_valid_ip(ip) and 0 <= int(mask) <= 32

if __name__ == '__main__':
    print("=" * 60)
    print("RPi HA DNS Stack - Web Setup UI")
    print("=" * 60)
    print(f"Repository root: {REPO_ROOT}")
    print(f"Access the setup wizard at: http://localhost:5555")
    print("=" * 60)
    app.run(host='0.0.0.0', port=5555, debug=False)
