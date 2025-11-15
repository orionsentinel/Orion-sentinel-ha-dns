#!/usr/bin/env python3
"""
Signal Webhook Bridge
Receives webhook calls from Alertmanager and forwards them to a hosted Signal webhook service
"""
from flask import Flask, request, jsonify
import requests
import os
import json
import logging

app = Flask(__name__)
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# Configuration from environment variables
SIGNAL_WEBHOOK_URL = os.environ.get('SIGNAL_WEBHOOK_URL', 'https://api.callmebot.com/signal/send.php')
SIGNAL_PHONE_NUMBER = os.environ.get('SIGNAL_PHONE_NUMBER', '')
SIGNAL_API_KEY = os.environ.get('SIGNAL_API_KEY', '')

@app.route('/health')
def health():
    """Health check endpoint"""
    return jsonify({'status': 'healthy', 'service': 'signal-webhook-bridge'})

@app.route('/v1/send', methods=['POST'])
def send_signal():
    """
    Receive webhook from Alertmanager and forward to Signal
    """
    try:
        data = request.json
        logger.info(f"Received webhook: {json.dumps(data, indent=2)}")
        
        # Extract alerts from Alertmanager payload
        if 'alerts' not in data:
            return jsonify({'error': 'No alerts in payload'}), 400
            
        alerts = data['alerts']
        if not alerts:
            return jsonify({'status': 'no alerts to send'}), 200
        
        # Format message for Signal
        messages = []
        for alert in alerts:
            status = alert.get('status', 'unknown')
            alertname = alert.get('labels', {}).get('alertname', 'Unknown Alert')
            severity = alert.get('labels', {}).get('severity', 'info')
            description = alert.get('annotations', {}).get('description', 'No description')
            
            emoji = '🔴' if status == 'firing' else '✅'
            message = f"{emoji} {alertname}\n"
            message += f"Status: {status.upper()}\n"
            message += f"Severity: {severity.upper()}\n"
            message += f"Description: {description}"
            messages.append(message)
        
        combined_message = "\n\n".join(messages)
        
        # Send to Signal via hosted webhook service (CallMeBot as example)
        if not SIGNAL_PHONE_NUMBER or not SIGNAL_API_KEY:
            logger.warning("Signal credentials not configured, skipping send")
            return jsonify({
                'status': 'skipped',
                'reason': 'credentials not configured',
                'message': combined_message
            }), 200
        
        # Format for CallMeBot Signal API
        params = {
            'phone': SIGNAL_PHONE_NUMBER,
            'apikey': SIGNAL_API_KEY,
            'text': combined_message
        }
        
        logger.info(f"Sending to Signal: {combined_message[:100]}...")
        response = requests.get(SIGNAL_WEBHOOK_URL, params=params, timeout=10)
        
        if response.status_code == 200:
            logger.info("Successfully sent to Signal")
            return jsonify({'status': 'sent', 'message': combined_message}), 200
        else:
            logger.error(f"Failed to send to Signal: {response.status_code} - {response.text}")
            return jsonify({
                'status': 'failed',
                'error': response.text,
                'message': combined_message
            }), 500
            
    except Exception as e:
        logger.error(f"Error processing webhook: {str(e)}", exc_info=True)
        return jsonify({'error': str(e)}), 500

@app.route('/test', methods=['POST'])
def test_notification():
    """Test endpoint to send a test notification"""
    try:
        message = request.json.get('message', 'Test notification from RPi HA DNS Stack')
        
        if not SIGNAL_PHONE_NUMBER or not SIGNAL_API_KEY:
            return jsonify({
                'status': 'error',
                'message': 'Signal credentials not configured'
            }), 400
        
        params = {
            'phone': SIGNAL_PHONE_NUMBER,
            'apikey': SIGNAL_API_KEY,
            'text': message
        }
        
        response = requests.get(SIGNAL_WEBHOOK_URL, params=params, timeout=10)
        
        if response.status_code == 200:
            return jsonify({'status': 'sent', 'message': message}), 200
        else:
            return jsonify({
                'status': 'failed',
                'error': response.text
            }), 500
            
    except Exception as e:
        logger.error(f"Error sending test notification: {str(e)}")
        return jsonify({'error': str(e)}), 500

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=8080)
