#!/usr/bin/env python3
from flask import Flask, jsonify
from prometheus_client import Counter, Gauge, generate_latest, CONTENT_TYPE_LATEST
import docker
import requests
import os
import time
from datetime import datetime

app = Flask(__name__)
client = docker.from_env()

# Prometheus metrics
restart_counter = Counter('ai_watchdog_restarts_total', 'Number of container restarts performed', ['container'])
container_health_gauge = Gauge('ai_watchdog_container_health', 'Container health status', ['container'])
uptime_gauge = Gauge('ai_watchdog_uptime_seconds', 'Watchdog uptime in seconds')
containers_monitored_gauge = Gauge('ai_watchdog_containers_monitored', 'Number of containers being monitored')

WATCHLIST = ['pihole_primary', 'pihole_secondary', 'unbound_primary', 'unbound_secondary', 'keepalived']

# Signal webhook bridge configuration
SIGNAL_BRIDGE_URL = os.environ.get('SIGNAL_BRIDGE_URL', 'http://signal-webhook-bridge:8080/test')

# Restart tracking with exponential backoff
restart_history = {}
MAX_RESTARTS_PER_HOUR = 5
start_time = time.time()
last_check_time = None

def get_uptime():
    """Get watchdog uptime in seconds"""
    return time.time() - start_time

def should_restart_container(container_name):
    """Check if container should be restarted (rate limiting)"""
    current_hour = datetime.now().strftime('%Y%m%d%H')
    key = f"{container_name}_{current_hour}"
    
    if key not in restart_history:
        restart_history[key] = 0
    
    if restart_history[key] >= MAX_RESTARTS_PER_HOUR:
        send_signal_notification(
            f"⚠️ AI-Watchdog: Container {container_name} restart limit exceeded "
            f"({MAX_RESTARTS_PER_HOUR}/hour). Manual intervention required."
        )
        return False
    
    restart_history[key] += 1
    return True

def send_signal_notification(message):
    """Send notification via Signal webhook bridge"""
    try:
        response = requests.post(
            SIGNAL_BRIDGE_URL,
            json={'message': message},
            timeout=5
        )
        if response.status_code == 200:
            print(f"Signal notification sent: {message}")
        else:
            print(f"Failed to send Signal notification: {response.status_code}")
    except Exception as e:
        print(f"Error sending Signal notification: {str(e)}")

@app.route('/')
def index():
    return jsonify({'status': 'ok', 'watched': WATCHLIST})

@app.route('/health')
def health():
    """Detailed health endpoint"""
    global last_check_time
    return jsonify({
        'status': 'healthy',
        'uptime_seconds': get_uptime(),
        'containers_monitored': len(WATCHLIST),
        'last_check': last_check_time,
        'watchlist': WATCHLIST
    })

@app.route('/metrics')
def metrics():
    """Prometheus metrics endpoint"""
    # Update uptime gauge
    uptime_gauge.set(get_uptime())
    containers_monitored_gauge.set(len(WATCHLIST))
    
    # Update health status for each container
    for name in WATCHLIST:
        try:
            c = client.containers.get(name)
            health_status = 1 if c.status == 'running' else 0
            container_health_gauge.labels(container=name).set(health_status)
        except docker.errors.NotFound:
            container_health_gauge.labels(container=name).set(0)
    
    return generate_latest(), 200, {'Content-Type': CONTENT_TYPE_LATEST}

@app.route('/check')
def check():
    """Check and restart unhealthy containers"""
    global last_check_time
    last_check_time = datetime.now().isoformat()
    
    result = {}
    restarted_containers = []
    rate_limited_containers = []
    
    for name in WATCHLIST:
        try:
            c = client.containers.get(name)
            running = c.status == 'running'
            result[name] = {'status': c.status}
            
            if not running:
                if should_restart_container(name):
                    c.restart()
                    restart_counter.labels(container=name).inc()
                    result[name]['action'] = 'restarted'
                    restarted_containers.append(name)
                else:
                    result[name]['action'] = 'rate_limited'
                    rate_limited_containers.append(name)
        except docker.errors.NotFound:
            result[name] = {'status': 'not_found'}
    
    # Send Signal notification if any containers were restarted
    if restarted_containers:
        message = f"🔧 AI-Watchdog: Restarted containers: {', '.join(restarted_containers)}"
        send_signal_notification(message)
    
    # Send alert for rate-limited containers
    if rate_limited_containers:
        message = f"🚨 AI-Watchdog: Rate limit reached for: {', '.join(rate_limited_containers)}"
        send_signal_notification(message)
    
    return jsonify(result)

if __name__ == '__main__':
    print(f"AI Watchdog starting...")
    print(f"Monitoring: {WATCHLIST}")
    print(f"Max restarts per hour: {MAX_RESTARTS_PER_HOUR}")
    app.run(host='0.0.0.0', port=5000)
