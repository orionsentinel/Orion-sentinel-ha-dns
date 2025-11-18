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
import hashlib
from argon2 import PasswordHasher
from pathlib import Path
from datetime import timedelta
import logging
logging.basicConfig(level=logging.INFO)
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

@app.route('/api/prerequisites/install', methods=['POST'])
def install_prerequisites():
    """Install missing prerequisites"""
    try:
        component = request.json.get('component')
        
        if component == 'docker':
            result = install_docker()
        elif component == 'docker_compose':
            result = install_docker_compose()
        else:
            return jsonify({'success': False, 'error': f'Unknown component: {component}'}), 400
        
        return jsonify(result)
    except Exception as e:
        return jsonify({'success': False, 'error': str(e)}), 500

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

@app.route('/api/sso-config', methods=['GET', 'POST'])
def sso_config():
    """Get or save SSO configuration"""
    if request.method == 'POST':
        config = request.json
        session['sso_config'] = config
        return jsonify({'success': True})
    
    return jsonify(session.get('sso_config', {
        'enabled': False,
        'admin_email': 'admin@rpi-dns-stack.local',
        'admin_displayname': 'Admin User',
        'enable_2fa': True,
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
        sso = session.get('sso_config', {})
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
            'WEBPASSWORD': PasswordHasher().hash(str(security.get('pihole_password', 'changeme'))),
            'GF_SECURITY_ADMIN_PASSWORD': PasswordHasher().hash(str(security.get('grafana_password', 'changeme'))),
        }
        
        # Add Signal configuration if enabled
        if signal.get('enabled'):
            replacements['SIGNAL_NUMBER'] = signal.get('signal_number', '')
            replacements['SIGNAL_RECIPIENTS'] = signal.get('signal_recipients', '')
        
        # Add SSO configuration if enabled
        if sso.get('enabled'):
            replacements['SSO_ADMIN_EMAIL'] = sso.get('admin_email', 'admin@rpi-dns-stack.local')
            replacements['SSO_ADMIN_DISPLAYNAME'] = sso.get('admin_displayname', 'Admin User')
        
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
        
        # Add SSO enabled flag as comment if enabled
        if sso.get('enabled'):
            sso_comment = f"\n# SSO Configuration Enabled\n"
            sso_comment += f"# SSO_ENABLED=true\n"
            env_content += sso_comment
        
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
    """Execute deployment automatically"""
    try:
        deployment = session.get('deployment_option', 'HighAvail_2Pi1P1U')
        node_role_config = session.get('node_role_config', {'node_role': 'primary', 'primary_node_ip': ''})
        network = session.get('network_config', DEFAULT_CONFIG)
        
        # Store deployment status in session
        session['deployment_status'] = 'starting'
        session['deployment_logs'] = []
        
        logs = []
        
        # Get deployment script path
        if deployment == 'HighAvail_1Pi2P2U':
            deploy_dir = REPO_ROOT / 'deployments' / 'HighAvail_1Pi2P2U'
        elif deployment == 'HighAvail_2Pi1P1U':
            base_path = REPO_ROOT / 'deployments' / 'HighAvail_2Pi1P1U'
            node_role = node_role_config.get('node_role', 'primary')
            deploy_dir = base_path / ('node1' if node_role == 'primary' else 'node2')
        elif deployment == 'HighAvail_2Pi2P2U':
            base_path = REPO_ROOT / 'deployments' / 'HighAvail_2Pi2P2U'
            node_role = node_role_config.get('node_role', 'primary')
            deploy_dir = base_path / ('node1' if node_role == 'primary' else 'node2')
        else:
            return jsonify({'success': False, 'error': 'Invalid deployment option'}), 400
        
        logs.append(f"Deploying to: {deploy_dir}")
        
        # Step 1: Create Docker network if it doesn't exist
        logs.append("Checking Docker network...")
        network_check = subprocess.run(
            ['docker', 'network', 'inspect', 'dns_net'],
            capture_output=True,
            timeout=10
        )
        
        if network_check.returncode != 0:
            logs.append("Creating macvlan network...")
            network_create = subprocess.run(
                [
                    'docker', 'network', 'create',
                    '-d', 'macvlan',
                    f'--subnet={network.get("SUBNET", "192.168.8.0/24")}',
                    f'--gateway={network.get("GATEWAY", "192.168.8.1")}',
                    '-o', f'parent={network.get("NETWORK_INTERFACE", "eth0")}',
                    'dns_net'
                ],
                capture_output=True,
                text=True,
                timeout=30
            )
            
            if network_create.returncode == 0:
                logs.append("✓ Docker network created successfully")
            else:
                error_msg = network_create.stderr.strip() if network_create.stderr else "Unknown error"
                logs.append(f"✗ Network creation failed: {error_msg}")
                return jsonify({
                    'success': False,
                    'error': f'Failed to create Docker network: {error_msg}',
                    'logs': logs
                }), 500
        else:
            logs.append("✓ Docker network already exists")
        
        # Step 2: Navigate to deployment directory and deploy
        if not deploy_dir.exists():
            return jsonify({
                'success': False,
                'error': f'Deployment directory not found: {deploy_dir}',
                'logs': logs
            }), 500
        
        logs.append(f"Deploying from: {deploy_dir}")
        
        # Step 3: Deploy with docker compose
        logs.append("Starting docker compose deployment...")
        deploy_process = subprocess.run(
            ['docker', 'compose', 'up', '-d'],
            cwd=str(deploy_dir),
            capture_output=True,
            text=True,
            timeout=300  # 5 minute timeout
        )
        
        if deploy_process.returncode == 0:
            logs.append("✓ Docker Compose deployment successful")
            logs.append("")
            logs.append("Deployment Output:")
            logs.append(deploy_process.stdout)
            
            # Wait a bit for containers to start
            import time
            time.sleep(5)
            
            # Get container status
            logs.append("")
            logs.append("Checking container status...")
            status_process = subprocess.run(
                ['docker', 'compose', 'ps'],
                cwd=str(deploy_dir),
                capture_output=True,
                text=True,
                timeout=30
            )
            
            if status_process.returncode == 0:
                logs.append(status_process.stdout)
            
            session['deployment_status'] = 'success'
            session['deployment_logs'] = logs
            
            # Generate access URLs
            primary_dns = network.get('PRIMARY_DNS_IP', '192.168.8.251')
            secondary_dns = network.get('SECONDARY_DNS_IP', '192.168.8.252')
            host_ip = network.get('HOST_IP', '192.168.8.250')
            
            return jsonify({
                'success': True,
                'message': 'Deployment completed successfully!',
                'logs': logs,
                'urls': {
                    'pihole_primary': f'http://{primary_dns}/admin',
                    'pihole_secondary': f'http://{secondary_dns}/admin',
                    'grafana': f'http://{host_ip}:3000'
                },
                'deployment_path': str(deploy_dir),
                'node_role': node_role_config.get('node_role', 'primary')
            })
        else:
            error_output = deploy_process.stderr.strip() if deploy_process.stderr else "Unknown error"
            logs.append(f"✗ Deployment failed")
            logs.append("")
            logs.append("Error Output:")
            logs.append(error_output)
            
            session['deployment_status'] = 'failed'
            session['deployment_logs'] = logs
            
            return jsonify({
                'success': False,
                'error': 'Docker Compose deployment failed',
                'logs': logs,
                'stderr': error_output
            }), 500
            
    except subprocess.TimeoutExpired:
        logs.append("✗ Deployment timed out")
        session['deployment_status'] = 'timeout'
        return jsonify({
            'success': False,
            'error': 'Deployment timed out (took longer than 5 minutes)',
            'logs': logs
        }), 500
    except Exception as e:
        logs.append(f"✗ Unexpected error: {str(e)}")
        session['deployment_status'] = 'error'
        return jsonify({
            'success': False,
            'error': str(e),
            'logs': logs
        }), 500

@app.route('/api/deployment-status', methods=['GET'])
def deployment_status():
    """Get current deployment status"""
    status = session.get('deployment_status', 'not_started')
    return jsonify({'status': status})

@app.route('/api/deploy-sso', methods=['POST'])
def deploy_sso():
    """Deploy SSO stack with Authelia"""
    try:
        sso_config = session.get('sso_config', {})
        security = session.get('security_config', {})
        network = session.get('network_config', DEFAULT_CONFIG)
        
        if not sso_config.get('enabled'):
            return jsonify({'success': False, 'error': 'SSO is not enabled'}), 400
        
        logs = []
        logs.append("Starting SSO deployment...")
        
        # SSO stack directory
        sso_dir = REPO_ROOT / 'stacks' / 'sso'
        
        if not sso_dir.exists():
            return jsonify({'success': False, 'error': 'SSO stack directory not found'}), 500
        
        # Step 1: Generate secrets
        logs.append("Generating SSO secrets...")
        secrets_script = sso_dir / 'generate-secrets.sh'
        
        if secrets_script.exists():
            # Run generate-secrets.sh with admin password
            admin_password = security.get('pihole_password', 'changeme')  # Use same as Pi-hole for simplicity
            
            secret_process = subprocess.Popen(
                ['bash', str(secrets_script)],
                stdin=subprocess.PIPE,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                text=True,
                cwd=str(sso_dir)
            )
            
            # Provide password inputs
            stdout, stderr = secret_process.communicate(
                input=f"{admin_password}\n{admin_password}\n",
                timeout=60
            )
            
            if secret_process.returncode == 0:
                logs.append("✓ SSO secrets generated successfully")
                logs.append(stdout[:500])  # Include first 500 chars of output
            else:
                logs.append(f"✗ Failed to generate secrets: {stderr}")
                return jsonify({
                    'success': False,
                    'error': 'Failed to generate SSO secrets',
                    'logs': logs
                }), 500
        else:
            logs.append("⚠ Secrets generation script not found, using defaults")
        
        # Step 2: Update configuration with user settings
        logs.append("Updating SSO configuration...")
        users_db_file = sso_dir / 'authelia' / 'users_database.yml'
        
        if users_db_file.exists():
            content = users_db_file.read_text()
            # Update email and display name
            content = content.replace('admin@rpi-dns-stack.local', sso_config.get('admin_email', 'admin@rpi-dns-stack.local'))
            content = content.replace('Admin User', sso_config.get('admin_displayname', 'Admin User'))
            users_db_file.write_text(content)
            logs.append("✓ User database updated")
        
        # Step 3: Deploy SSO stack
        logs.append("Deploying SSO containers...")
        deploy_process = subprocess.run(
            ['docker', 'compose', 'up', '-d'],
            cwd=str(sso_dir),
            capture_output=True,
            text=True,
            timeout=180
        )
        
        if deploy_process.returncode == 0:
            logs.append("✓ SSO stack deployed successfully")
            logs.append(deploy_process.stdout)
            
            # Wait for services to start
            import time
            time.sleep(5)
            
            # Check container status
            logs.append("")
            logs.append("Checking SSO container status...")
            status_process = subprocess.run(
                ['docker', 'compose', 'ps'],
                cwd=str(sso_dir),
                capture_output=True,
                text=True,
                timeout=30
            )
            
            if status_process.returncode == 0:
                logs.append(status_process.stdout)
            
            host_ip = network.get('HOST_IP', '192.168.8.250')
            
            return jsonify({
                'success': True,
                'message': 'SSO deployed successfully!',
                'logs': logs,
                'urls': {
                    'authelia': f'http://{host_ip}:9091',
                    'oauth2_proxy': f'http://{host_ip}:4180'
                }
            })
        else:
            logs.append("✗ SSO deployment failed")
            logs.append(deploy_process.stderr)
            
            return jsonify({
                'success': False,
                'error': 'SSO deployment failed',
                'logs': logs
            }), 500
            
    except subprocess.TimeoutExpired:
        logs.append("✗ SSO deployment timed out")
        return jsonify({
            'success': False,
            'error': 'SSO deployment timed out',
            'logs': logs
        }), 500
    except Exception as e:
        logging.exception("Unexpected error during SSO deployment")
        logs.append("✗ Unexpected error occurred")
        return jsonify({
            'success': False,
            'error': 'An unexpected error occurred.',
            'logs': logs
        }), 500

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

def install_docker():
    """Install Docker if not present"""
    try:
        # Check if already installed
        check = check_docker()
        if check['status']:
            return {'success': True, 'message': 'Docker is already installed'}
        
        # Determine if we need sudo
        import os
        use_sudo = os.geteuid() != 0
        
        # Install Docker using the official script
        install_cmd = 'curl -fsSL https://get.docker.com | sh'
        if use_sudo:
            install_cmd = f'sudo {install_cmd}'
        
        result = subprocess.run(
            install_cmd,
            shell=True,
            capture_output=True,
            text=True,
            timeout=300  # 5 minute timeout for installation
        )
        
        if result.returncode != 0:
            return {
                'success': False,
                'message': f'Docker installation failed: {result.stderr}'
            }
        
        # Add current user to docker group
        if use_sudo:
            user = os.environ.get('USER', os.environ.get('LOGNAME'))
            if user:
                subprocess.run(['sudo', 'usermod', '-aG', 'docker', user], timeout=10)
        
        return {
            'success': True,
            'message': 'Docker installed successfully. You may need to log out and back in for Docker permissions to take effect.'
        }
    except subprocess.TimeoutExpired:
        return {'success': False, 'message': 'Docker installation timed out'}
    except Exception as e:
        return {'success': False, 'message': f'Docker installation error: {str(e)}'}

def install_docker_compose():
    """Install Docker Compose plugin if not present"""
    try:
        # Check if already installed
        check = check_docker_compose()
        if check['status']:
            return {'success': True, 'message': 'Docker Compose is already installed'}
        
        # Determine if we need sudo
        import os
        use_sudo = os.geteuid() != 0
        sudo_prefix = 'sudo ' if use_sudo else ''
        
        # Update package list
        result = subprocess.run(
            f'{sudo_prefix}apt-get update -qq',
            shell=True,
            capture_output=True,
            text=True,
            timeout=60
        )
        
        # Install docker-compose-plugin
        result = subprocess.run(
            f'{sudo_prefix}apt-get install -y docker-compose-plugin',
            shell=True,
            capture_output=True,
            text=True,
            timeout=180  # 3 minute timeout
        )
        
        if result.returncode != 0:
            return {
                'success': False,
                'message': f'Docker Compose installation failed: {result.stderr}'
            }
        
        return {
            'success': True,
            'message': 'Docker Compose installed successfully'
        }
    except subprocess.TimeoutExpired:
        return {'success': False, 'message': 'Docker Compose installation timed out'}
    except Exception as e:
        return {'success': False, 'message': f'Docker Compose installation error: {str(e)}'}

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
