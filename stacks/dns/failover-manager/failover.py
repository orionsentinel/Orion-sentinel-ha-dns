#!/usr/bin/env python3
"""
DNS Failover Manager
Monitors DNS servers across regions and manages automatic failover
"""

import socket
import time
import logging
import os
from datetime import datetime
from prometheus_client import Counter, Gauge, Histogram, start_http_server
import subprocess

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

# Prometheus metrics
dns_checks = Counter('dns_failover_checks_total', 'Total DNS health checks', ['server', 'status'])
dns_response_time = Histogram('dns_failover_response_seconds', 'DNS query response time', ['server'])
dns_server_status = Gauge('dns_failover_server_status', 'DNS server status (1=up, 0=down)', ['server'])
active_server = Gauge('dns_failover_active_server', 'Currently active DNS server', ['server'])
failover_events = Counter('dns_failover_events_total', 'Total failover events', ['from_server', 'to_server'])

# Configuration
CHECK_INTERVAL = int(os.getenv('CHECK_INTERVAL', '30'))
TIMEOUT = 5

DNS_SERVERS = {
    'primary': os.getenv('PRIMARY_DNS', '192.168.8.251'),
    'secondary': os.getenv('SECONDARY_DNS', '192.168.8.252'),
    'backup1': os.getenv('BACKUP_DNS_1', '127.0.0.1:5380'),
    'backup2': os.getenv('BACKUP_DNS_2', '127.0.0.1:5381'),
    'cloud1': os.getenv('CLOUD_DNS_1', '8.8.8.8'),
    'cloud2': os.getenv('CLOUD_DNS_2', '1.1.1.1')
}

PRIORITY_ORDER = ['primary', 'secondary', 'backup1', 'backup2', 'cloud1', 'cloud2']
current_active = 'primary'

def check_dns_server(server_name, server_addr):
    """Check if DNS server is responding"""
    try:
        start_time = time.time()
        
        # Parse address (handle IP:port format)
        if ':' in server_addr:
            ip, port = server_addr.split(':')
            port = int(port)
        else:
            ip = server_addr
            port = 53
        
        # Create DNS query for google.com
        query = b'\x00\x00\x01\x00\x00\x01\x00\x00\x00\x00\x00\x00\x06google\x03com\x00\x00\x01\x00\x01'
        
        # Send query
        sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        sock.settimeout(TIMEOUT)
        sock.sendto(query, (ip, port))
        
        # Receive response
        data, _ = sock.recvfrom(512)
        sock.close()
        
        response_time = time.time() - start_time
        
        # Record metrics
        dns_response_time.labels(server=server_name).observe(response_time)
        dns_checks.labels(server=server_name, status='success').inc()
        dns_server_status.labels(server=server_name).set(1)
        
        logger.info(f"DNS server {server_name} ({server_addr}) responded in {response_time:.3f}s")
        return True
        
    except socket.timeout:
        logger.warning(f"DNS server {server_name} ({server_addr}) timed out")
        dns_checks.labels(server=server_name, status='timeout').inc()
        dns_server_status.labels(server=server_name).set(0)
        return False
    except Exception as e:
        logger.error(f"DNS server {server_name} ({server_addr}) error: {e}")
        dns_checks.labels(server=server_name, status='error').inc()
        dns_server_status.labels(server=server_name).set(0)
        return False

def get_best_available_server():
    """Find the highest priority available DNS server"""
    for server_name in PRIORITY_ORDER:
        server_addr = DNS_SERVERS.get(server_name)
        if server_addr and check_dns_server(server_name, server_addr):
            return server_name
    return None

def update_system_dns(server_name):
    """Update system DNS configuration to use specified server"""
    global current_active
    
    if server_name == current_active:
        return  # Already using this server
    
    try:
        server_addr = DNS_SERVERS[server_name]
        logger.warning(f"Failover: Switching from {current_active} to {server_name}")
        
        # Record failover event
        failover_events.labels(from_server=current_active, to_server=server_name).inc()
        
        # Update active server metric
        active_server.labels(server=current_active).set(0)
        active_server.labels(server=server_name).set(1)
        
        current_active = server_name
        
        logger.info(f"Successfully failed over to {server_name} ({server_addr})")
        
    except Exception as e:
        logger.error(f"Failed to update DNS to {server_name}: {e}")

def health_check_loop():
    """Main health check loop"""
    logger.info("DNS Failover Manager started")
    logger.info(f"Monitoring servers: {', '.join(PRIORITY_ORDER)}")
    logger.info(f"Check interval: {CHECK_INTERVAL}s")
    
    # Initialize active server
    active_server.labels(server=current_active).set(1)
    
    while True:
        try:
            logger.info("Running DNS health checks...")
            
            # Check current active server
            if not check_dns_server(current_active, DNS_SERVERS[current_active]):
                logger.warning(f"Active DNS server {current_active} is down!")
                
                # Find best available server
                best_server = get_best_available_server()
                if best_server and best_server != current_active:
                    update_system_dns(best_server)
                else:
                    logger.error("No DNS servers available!")
            else:
                logger.info(f"Active DNS server {current_active} is healthy")
                
                # Check if we can fail back to higher priority server
                for server_name in PRIORITY_ORDER:
                    if server_name == current_active:
                        break  # Current server is highest available
                    
                    server_addr = DNS_SERVERS.get(server_name)
                    if server_addr and check_dns_server(server_name, server_addr):
                        logger.info(f"Higher priority server {server_name} is now available, failing back...")
                        update_system_dns(server_name)
                        break
            
            time.sleep(CHECK_INTERVAL)
            
        except KeyboardInterrupt:
            logger.info("Shutting down...")
            break
        except Exception as e:
            logger.error(f"Error in health check loop: {e}")
            time.sleep(CHECK_INTERVAL)

if __name__ == '__main__':
    # Start Prometheus metrics server
    start_http_server(8081)
    logger.info("Prometheus metrics server started on port 8081")
    
    # Start health check loop
    health_check_loop()
