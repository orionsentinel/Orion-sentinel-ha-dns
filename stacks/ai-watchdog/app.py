#!/usr/bin/env python3
from flask import Flask, jsonify
from prometheus_client import Counter, generate_latest, CONTENT_TYPE_LATEST
import docker
import requests
import os
import time

app = Flask(__name__)
client = docker.from_env()

restart_counter = Counter('ai_watchdog_restarts_total', 'Number of container restarts performed')

WATCHLIST = ['pihole_primary', 'pihole_secondary', 'unbound_primary', 'unbound_secondary', 'keepalived']

# Signal webhook bridge configuration
SIGNAL_BRIDGE_URL = os.environ.get('SIGNAL_BRIDGE_URL', 'http://signal-webhook-bridge:8080/test')

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

@app.route('/metrics')
def metrics():
    return generate_latest(), 200, {'Content-Type': CONTENT_TYPE_LATEST}

@app.route('/check')
def check():
    result = {}
    restarted_containers = []
    
    for name in WATCHLIST:
        try:
            c = client.containers.get(name)
            running = c.status == 'running'
            result[name] = {'status': c.status}
            if not running:
                c.restart()
                restart_counter.inc()
                result[name]['action'] = 'restarted'
                restarted_containers.append(name)
        except docker.errors.NotFound:
            result[name] = {'status': 'not_found'}
    
    # Send Signal notification if any containers were restarted
    if restarted_containers:
        message = f"🔧 AI-Watchdog: Restarted containers: {', '.join(restarted_containers)}"
        send_signal_notification(message)
    
    return jsonify(result)

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000)
