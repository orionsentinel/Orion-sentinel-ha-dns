#!/usr/bin/env python3
"""
DNS Health HTTP Service

Provides HTTP endpoint for health status checking.
Useful for external monitoring systems, load balancers, etc.

Endpoints:
  GET /health - Returns aggregated health status
  GET /health/detailed - Returns detailed health check results
  GET /ready - Kubernetes-style readiness probe
  GET /live - Kubernetes-style liveness probe
"""

import sys
import json
from http.server import HTTPServer, BaseHTTPRequestHandler
from datetime import datetime
import os

# Import the health checker module
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from health_checker import HealthChecker


class HealthHandler(BaseHTTPRequestHandler):
    """HTTP request handler for health endpoints"""
    
    def do_GET(self):
        """Handle GET requests"""
        
        if self.path == "/health":
            self.handle_health_simple()
        elif self.path == "/health/detailed":
            self.handle_health_detailed()
        elif self.path == "/ready":
            self.handle_readiness()
        elif self.path == "/live":
            self.handle_liveness()
        else:
            self.send_error(404, "Endpoint not found")
    
    def handle_health_simple(self):
        """Simple health check - just overall status"""
        checker = HealthChecker()
        results = checker.run_checks()
        
        status_code = 200 if results["status"] == "healthy" else 503
        
        response = {
            "status": results["status"],
            "timestamp": results["timestamp"],
            "errors_count": len(results["errors"])
        }
        
        self.send_json_response(response, status_code)
    
    def handle_health_detailed(self):
        """Detailed health check - all check results"""
        checker = HealthChecker()
        results = checker.run_checks()
        
        status_code = 200 if results["status"] in ["healthy", "degraded"] else 503
        
        self.send_json_response(results, status_code)
    
    def handle_readiness(self):
        """Kubernetes-style readiness probe"""
        checker = HealthChecker()
        results = checker.run_checks()
        
        # Ready if at least one Pi-hole and one Unbound are working
        pihole_ok = any(
            results["checks"].get(f"pihole_{role}", {}).get("status") == "pass"
            for role in ["primary", "secondary"]
        )
        unbound_ok = any(
            results["checks"].get(f"unbound_{role}", {}).get("status") == "pass"
            for role in ["primary", "secondary"]
        )
        
        ready = pihole_ok and unbound_ok
        status_code = 200 if ready else 503
        
        response = {
            "ready": ready,
            "timestamp": datetime.now().isoformat()
        }
        
        self.send_json_response(response, status_code)
    
    def handle_liveness(self):
        """Kubernetes-style liveness probe - just check if we're alive"""
        response = {
            "alive": True,
            "timestamp": datetime.now().isoformat()
        }
        
        self.send_json_response(response, 200)
    
    def send_json_response(self, data, status_code=200):
        """Send JSON response"""
        self.send_response(status_code)
        self.send_header("Content-Type", "application/json")
        self.send_header("Cache-Control", "no-cache")
        self.end_headers()
        
        response_json = json.dumps(data, indent=2)
        self.wfile.write(response_json.encode())
    
    def log_message(self, format, *args):
        """Override to customize logging"""
        # Log in structured format
        print(f"[{datetime.now().isoformat()}] {self.address_string()} - {format % args}")


def main():
    """Main entry point"""
    import argparse
    
    parser = argparse.ArgumentParser(description="DNS Health HTTP Service")
    parser.add_argument(
        "--port",
        type=int,
        default=8888,
        help="Port to listen on (default: 8888)"
    )
    parser.add_argument(
        "--host",
        default="0.0.0.0",
        help="Host to bind to (default: 0.0.0.0)"
    )
    
    args = parser.parse_args()
    
    server_address = (args.host, args.port)
    httpd = HTTPServer(server_address, HealthHandler)
    
    print(f"Starting DNS Health HTTP Service on {args.host}:{args.port}")
    print(f"Endpoints:")
    print(f"  GET http://{args.host}:{args.port}/health - Simple health status")
    print(f"  GET http://{args.host}:{args.port}/health/detailed - Detailed status")
    print(f"  GET http://{args.host}:{args.port}/ready - Readiness probe")
    print(f"  GET http://{args.host}:{args.port}/live - Liveness probe")
    
    try:
        httpd.serve_forever()
    except KeyboardInterrupt:
        print("\nShutting down...")
        httpd.shutdown()


if __name__ == "__main__":
    main()
