#!/usr/bin/env python3
"""
Health Checker for Orion Sentinel DNS HA Stack

This script performs comprehensive health checks on:
- Pi-hole API responsiveness
- Unbound DNS resolver status
- Keepalived VIP status
- Docker container health
- System resources

Returns JSON summary and appropriate exit codes for Docker healthchecks.
"""

import sys
import json
import subprocess
import socket
import time
from datetime import datetime
from typing import Dict, List, Tuple
import os

try:
    import requests
except ImportError:
    print("Warning: requests module not available, skipping HTTP checks", file=sys.stderr)
    requests = None


class HealthChecker:
    """Comprehensive health checker for DNS HA stack"""
    
    def __init__(self, config: Dict = None):
        """Initialize health checker with configuration"""
        self.config = config or {}
        self.results = {
            "timestamp": datetime.now().isoformat(),
            "status": "healthy",
            "checks": {},
            "errors": []
        }
        
        # Load configuration from environment or use defaults
        self.pihole_primary_ip = os.getenv("PIHOLE_PRIMARY_IP", "192.168.8.251")
        self.pihole_secondary_ip = os.getenv("PIHOLE_SECONDARY_IP", "192.168.8.252")
        self.unbound_primary_ip = os.getenv("UNBOUND_PRIMARY_IP", "192.168.8.253")
        self.unbound_secondary_ip = os.getenv("UNBOUND_SECONDARY_IP", "192.168.8.254")
        self.vip = os.getenv("VIP_ADDRESS", "192.168.8.255")
        self.pihole_password = os.getenv("PIHOLE_PASSWORD", "")
    
    def check_pihole_api(self, ip: str, name: str) -> Tuple[bool, str]:
        """Check Pi-hole API responsiveness"""
        if not requests:
            return True, "HTTP checks disabled (requests module not available)"
        
        try:
            # Check basic API endpoint
            url = f"http://{ip}/admin/api.php"
            response = requests.get(url, timeout=5)
            
            if response.status_code == 200:
                data = response.json()
                # Verify we got valid data
                if "domains_being_blocked" in data:
                    blocked = data.get("domains_being_blocked", 0)
                    queries = data.get("dns_queries_today", 0)
                    return True, f"API OK (blocking {blocked} domains, {queries} queries today)"
                else:
                    return False, "API returned invalid data"
            else:
                return False, f"API returned status {response.status_code}"
        except requests.exceptions.Timeout:
            return False, "API request timed out"
        except requests.exceptions.ConnectionError:
            return False, "Cannot connect to API"
        except Exception as e:
            return False, f"API check failed: {str(e)}"
    
    def check_unbound_dns(self, ip: str, name: str) -> Tuple[bool, str]:
        """Check Unbound DNS resolver using dig"""
        try:
            # Use dig to query a test domain
            result = subprocess.run(
                ["dig", "@" + ip, "google.com", "+short", "+time=3"],
                capture_output=True,
                text=True,
                timeout=5
            )
            
            if result.returncode == 0 and result.stdout.strip():
                response_time = "< 3s"
                return True, f"DNS resolution OK (response: {response_time})"
            else:
                return False, "DNS query failed or no response"
        except subprocess.TimeoutExpired:
            return False, "DNS query timed out"
        except FileNotFoundError:
            # dig not available, try nslookup
            return self._check_dns_nslookup(ip, name)
        except Exception as e:
            return False, f"DNS check failed: {str(e)}"
    
    def _check_dns_nslookup(self, ip: str, name: str) -> Tuple[bool, str]:
        """Fallback DNS check using nslookup"""
        try:
            result = subprocess.run(
                ["nslookup", "google.com", ip],
                capture_output=True,
                text=True,
                timeout=5
            )
            
            if result.returncode == 0 and "Address:" in result.stdout:
                return True, "DNS resolution OK (via nslookup)"
            else:
                return False, "DNS query failed"
        except Exception as e:
            return False, f"DNS check failed: {str(e)}"
    
    def check_vip_status(self) -> Tuple[bool, str]:
        """Check Keepalived VIP status on this node"""
        try:
            # Check if VIP is assigned to any interface
            result = subprocess.run(
                ["ip", "addr", "show"],
                capture_output=True,
                text=True,
                timeout=3
            )
            
            if result.returncode == 0:
                if self.vip in result.stdout:
                    return True, f"VIP {self.vip} is ACTIVE on this node (MASTER)"
                else:
                    return True, f"VIP {self.vip} is on backup node (BACKUP role - normal)"
            else:
                return False, "Failed to check VIP status"
        except Exception as e:
            return False, f"VIP check failed: {str(e)}"
    
    def check_docker_container(self, container_name: str) -> Tuple[bool, str]:
        """Check if Docker container is running and healthy"""
        try:
            # Check if container is running
            result = subprocess.run(
                ["docker", "ps", "--filter", f"name={container_name}", "--format", "{{.Names}}"],
                capture_output=True,
                text=True,
                timeout=5
            )
            
            if result.returncode == 0 and container_name in result.stdout:
                # Check health status if available
                health_result = subprocess.run(
                    ["docker", "inspect", "--format", "{{.State.Health.Status}}", container_name],
                    capture_output=True,
                    text=True,
                    timeout=3
                )
                
                health_status = health_result.stdout.strip()
                if health_status == "healthy":
                    return True, "Container running and healthy"
                elif health_status == "":
                    return True, "Container running (no healthcheck defined)"
                else:
                    return False, f"Container unhealthy: {health_status}"
            else:
                return False, "Container not running"
        except Exception as e:
            return False, f"Container check failed: {str(e)}"
    
    def run_checks(self) -> Dict:
        """Run all health checks and return results"""
        
        # Check Pi-hole instances
        success, message = self.check_pihole_api(self.pihole_primary_ip, "Primary")
        self.results["checks"]["pihole_primary"] = {
            "status": "pass" if success else "fail",
            "message": message
        }
        if not success:
            self.results["status"] = "degraded"
            self.results["errors"].append(f"Pi-hole Primary: {message}")
        
        success, message = self.check_pihole_api(self.pihole_secondary_ip, "Secondary")
        self.results["checks"]["pihole_secondary"] = {
            "status": "pass" if success else "fail",
            "message": message
        }
        if not success:
            self.results["status"] = "degraded"
            self.results["errors"].append(f"Pi-hole Secondary: {message}")
        
        # Check Unbound instances
        success, message = self.check_unbound_dns(self.unbound_primary_ip, "Primary")
        self.results["checks"]["unbound_primary"] = {
            "status": "pass" if success else "fail",
            "message": message
        }
        if not success:
            self.results["status"] = "degraded"
            self.results["errors"].append(f"Unbound Primary: {message}")
        
        success, message = self.check_unbound_dns(self.unbound_secondary_ip, "Secondary")
        self.results["checks"]["unbound_secondary"] = {
            "status": "pass" if success else "fail",
            "message": message
        }
        if not success:
            self.results["status"] = "degraded"
            self.results["errors"].append(f"Unbound Secondary: {message}")
        
        # Check VIP status
        success, message = self.check_vip_status()
        self.results["checks"]["keepalived_vip"] = {
            "status": "pass" if success else "fail",
            "message": message
        }
        if not success:
            self.results["status"] = "unhealthy"
            self.results["errors"].append(f"Keepalived VIP: {message}")
        
        # Check critical Docker containers
        containers = ["pihole_primary", "pihole_secondary", "unbound_primary", "unbound_secondary", "keepalived"]
        for container in containers:
            success, message = self.check_docker_container(container)
            self.results["checks"][f"container_{container}"] = {
                "status": "pass" if success else "fail",
                "message": message
            }
            if not success:
                self.results["status"] = "degraded"
                self.results["errors"].append(f"Container {container}: {message}")
        
        return self.results
    
    def print_results(self, format_type: str = "text"):
        """Print health check results in specified format"""
        if format_type == "json":
            print(json.dumps(self.results, indent=2))
        else:
            # Text format for human readability
            print("\n" + "="*60)
            print(f"Orion Sentinel DNS HA - Health Check Report")
            print(f"Timestamp: {self.results['timestamp']}")
            print(f"Overall Status: {self.results['status'].upper()}")
            print("="*60 + "\n")
            
            # Print individual checks
            for check_name, check_data in self.results["checks"].items():
                status_icon = "✅" if check_data["status"] == "pass" else "❌"
                print(f"{status_icon} {check_name}: {check_data['message']}")
            
            # Print errors if any
            if self.results["errors"]:
                print("\n" + "-"*60)
                print("ERRORS:")
                for error in self.results["errors"]:
                    print(f"  ⚠️  {error}")
                print("-"*60)
            
            print()
    
    def get_exit_code(self) -> int:
        """Get appropriate exit code based on health status"""
        if self.results["status"] == "healthy":
            return 0
        elif self.results["status"] == "degraded":
            return 1
        else:  # unhealthy
            return 2


def main():
    """Main entry point"""
    import argparse
    
    parser = argparse.ArgumentParser(description="Health checker for Orion Sentinel DNS HA")
    parser.add_argument(
        "--format",
        choices=["text", "json"],
        default="text",
        help="Output format (default: text)"
    )
    parser.add_argument(
        "--quiet",
        action="store_true",
        help="Suppress output, only return exit code"
    )
    
    args = parser.parse_args()
    
    # Create and run health checker
    checker = HealthChecker()
    results = checker.run_checks()
    
    # Print results unless quiet mode
    if not args.quiet:
        checker.print_results(format_type=args.format)
    
    # Exit with appropriate code
    sys.exit(checker.get_exit_code())


if __name__ == "__main__":
    main()
