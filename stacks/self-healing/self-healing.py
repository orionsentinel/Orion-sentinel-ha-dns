#!/usr/bin/env python3
"""
Self-Healing Service for DNS Stack
Monitors containers and network, auto-recovers from failures
"""

import docker
import time
import logging
import os
from datetime import datetime, timedelta
from prometheus_client import Counter, Gauge, start_http_server
from collections import defaultdict

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

# Prometheus metrics
container_restarts = Counter(
    'self_healing_container_restarts_total',
    'Total container restarts by self-healing',
    ['container']
)
network_recreations = Counter(
    'self_healing_network_recreations_total',
    'Total network recreations'
)
health_checks = Counter(
    'self_healing_health_checks_total',
    'Total health checks performed'
)
last_check_time = Gauge(
    'self_healing_last_check_timestamp',
    'Timestamp of last health check'
)
uptime = Gauge(
    'self_healing_uptime_seconds',
    'Self-healing service uptime in seconds'
)

# Configuration
CHECK_INTERVAL = int(os.getenv('CHECK_INTERVAL', '60'))  # seconds
MAX_RESTARTS_PER_HOUR = 3
NETWORK_NAME = 'dns_net'
NETWORK_SUBNET = os.getenv('SUBNET', '192.168.8.0/24')
NETWORK_GATEWAY = os.getenv('GATEWAY', '192.168.8.1')
NETWORK_INTERFACE = os.getenv('NETWORK_INTERFACE', 'eth0')

# Track restart history (per-hour)
restart_history = defaultdict(list)

# Monitored containers
MONITORED_CONTAINERS = [
    'pihole_primary',
    'pihole_secondary',
    'unbound_primary',
    'unbound_secondary',
    'keepalived'
]

def clean_restart_history():
    """Remove restart entries older than 1 hour"""
    one_hour_ago = datetime.now() - timedelta(hours=1)
    for container in list(restart_history.keys()):
        restart_history[container] = [
            ts for ts in restart_history[container]
            if ts > one_hour_ago
        ]

def can_restart(container_name):
    """Check if container can be restarted (rate limiting)"""
    clean_restart_history()
    return len(restart_history[container_name]) < MAX_RESTARTS_PER_HOUR

def record_restart(container_name):
    """Record a restart timestamp"""
    restart_history[container_name].append(datetime.now())

def check_network(client):
    """Verify dns_net network exists and has correct configuration"""
    try:
        network = client.networks.get(NETWORK_NAME)
        config = network.attrs.get('IPAM', {}).get('Config', [])
        
        if not config:
            logger.warning(f"Network {NETWORK_NAME} has no IPAM configuration")
            return False
        
        subnet = config[0].get('Subnet')
        gateway = config[0].get('Gateway')
        
        if subnet != NETWORK_SUBNET or gateway != NETWORK_GATEWAY:
            logger.warning(f"Network {NETWORK_NAME} misconfigured: subnet={subnet}, gateway={gateway}")
            return False
        
        logger.info(f"Network {NETWORK_NAME} is correctly configured")
        return True
        
    except docker.errors.NotFound:
        logger.error(f"Network {NETWORK_NAME} not found")
        return False
    except Exception as e:
        logger.error(f"Error checking network: {e}")
        return False

def recreate_network():
    """Recreate the dns_net network with proper configuration"""
    try:
        logger.warning("Attempting to recreate network...")
        
        # This requires docker CLI access
        import subprocess
        
        # Try to remove existing network
        subprocess.run(['docker', 'network', 'rm', NETWORK_NAME], 
                      stderr=subprocess.DEVNULL)
        
        # Create network
        result = subprocess.run([
            'docker', 'network', 'create',
            '-d', 'macvlan',
            '--subnet', NETWORK_SUBNET,
            '--gateway', NETWORK_GATEWAY,
            '-o', f'parent={NETWORK_INTERFACE}',
            NETWORK_NAME
        ], capture_output=True, text=True)
        
        if result.returncode == 0:
            logger.info(f"Successfully recreated network {NETWORK_NAME}")
            network_recreations.inc()
            return True
        else:
            logger.error(f"Failed to recreate network: {result.stderr}")
            return False
            
    except Exception as e:
        logger.error(f"Error recreating network: {e}")
        return False

def check_container_health(client, container_name):
    """Check if a container is healthy"""
    try:
        container = client.containers.get(container_name)
        
        # Check if container is running
        if container.status != 'running':
            logger.warning(f"Container {container_name} is not running (status: {container.status})")
            return False
        
        # Check health status if available
        health = container.attrs.get('State', {}).get('Health', {})
        if health:
            health_status = health.get('Status')
            if health_status != 'healthy':
                logger.warning(f"Container {container_name} is unhealthy (status: {health_status})")
                return False
        
        logger.info(f"Container {container_name} is healthy")
        return True
        
    except docker.errors.NotFound:
        logger.error(f"Container {container_name} not found")
        return False
    except Exception as e:
        logger.error(f"Error checking container {container_name}: {e}")
        return False

def restart_container(client, container_name):
    """Restart an unhealthy container"""
    try:
        if not can_restart(container_name):
            logger.error(f"Container {container_name} has reached max restarts/hour ({MAX_RESTARTS_PER_HOUR})")
            logger.error(f"Manual intervention required for {container_name}")
            return False
        
        logger.info(f"Restarting container {container_name}...")
        container = client.containers.get(container_name)
        container.restart()
        
        record_restart(container_name)
        container_restarts.labels(container=container_name).inc()
        
        logger.info(f"Successfully restarted {container_name}")
        return True
        
    except Exception as e:
        logger.error(f"Error restarting container {container_name}: {e}")
        return False

def health_check_loop():
    """Main health check loop"""
    start_time = time.time()
    client = docker.from_env()
    
    logger.info("Self-Healing Service started")
    logger.info(f"Monitoring containers: {', '.join(MONITORED_CONTAINERS)}")
    logger.info(f"Check interval: {CHECK_INTERVAL}s")
    logger.info(f"Max restarts per hour: {MAX_RESTARTS_PER_HOUR}")
    
    while True:
        try:
            health_checks.inc()
            last_check_time.set(time.time())
            uptime.set(time.time() - start_time)
            
            logger.info("Running health checks...")
            
            # Check network
            if not check_network(client):
                logger.warning("Network check failed, attempting recreation...")
                recreate_network()
            
            # Check each container
            for container_name in MONITORED_CONTAINERS:
                if not check_container_health(client, container_name):
                    logger.warning(f"Container {container_name} is unhealthy, attempting restart...")
                    restart_container(client, container_name)
            
            logger.info(f"Health check complete. Sleeping for {CHECK_INTERVAL}s...")
            time.sleep(CHECK_INTERVAL)
            
        except KeyboardInterrupt:
            logger.info("Shutting down...")
            break
        except Exception as e:
            logger.error(f"Error in health check loop: {e}")
            time.sleep(CHECK_INTERVAL)

if __name__ == '__main__':
    # Start Prometheus metrics server
    start_http_server(8080)
    logger.info("Prometheus metrics server started on port 8080")
    
    # Start health check loop
    health_check_loop()
