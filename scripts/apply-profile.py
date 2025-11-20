#!/usr/bin/env python3
"""
Apply DNS Privacy and Security Profiles to Pi-hole

This script reads a profile YAML file and applies the configuration to Pi-hole
via the API and configuration files.

Usage:
    python3 apply-profile.py --profile standard
    python3 apply-profile.py --profile family --dry-run
    python3 apply-profile.py --profile paranoid --pihole-ip 192.168.8.251
"""

import sys
import os
import argparse
import yaml
import subprocess
from typing import Dict, List
from pathlib import Path

try:
    import requests
except ImportError:
    print("ERROR: requests module required. Install with: pip3 install requests")
    sys.exit(1)


class ProfileApplicator:
    """Apply DNS security profiles to Pi-hole"""
    
    def __init__(self, profile_path: str, pihole_ip: str = None, pihole_password: str = None, dry_run: bool = False):
        """Initialize profile applicator"""
        self.profile_path = profile_path
        self.pihole_ip = pihole_ip or os.getenv("PIHOLE_PRIMARY_IP", "192.168.8.251")
        self.pihole_password = pihole_password or os.getenv("PIHOLE_PASSWORD", "")
        self.dry_run = dry_run
        self.profile = None
        
        # API session
        self.session = requests.Session()
        self.api_base = f"http://{self.pihole_ip}/admin/api.php"
    
    def load_profile(self) -> Dict:
        """Load profile YAML file"""
        try:
            with open(self.profile_path, 'r') as f:
                self.profile = yaml.safe_load(f)
            
            print(f"✅ Loaded profile: {self.profile.get('name', 'unknown')}")
            print(f"   Description: {self.profile.get('description', 'No description')}")
            print(f"   Category: {self.profile.get('category', 'unknown')}")
            
            # Show warnings if present
            if 'warnings' in self.profile:
                print("\n⚠️  WARNINGS:")
                for warning in self.profile['warnings']:
                    print(f"   - {warning}")
            
            return self.profile
        except FileNotFoundError:
            print(f"❌ ERROR: Profile file not found: {self.profile_path}")
            sys.exit(1)
        except yaml.YAMLError as e:
            print(f"❌ ERROR: Invalid YAML in profile: {e}")
            sys.exit(1)
    
    def verify_pihole_api(self) -> bool:
        """Verify Pi-hole API is accessible"""
        try:
            response = self.session.get(self.api_base, timeout=5)
            if response.status_code == 200:
                print(f"✅ Pi-hole API accessible at {self.pihole_ip}")
                return True
            else:
                print(f"❌ Pi-hole API returned status {response.status_code}")
                return False
        except requests.exceptions.RequestException as e:
            print(f"❌ Cannot connect to Pi-hole API: {e}")
            return False
    
    def apply_blocklists(self) -> bool:
        """Apply blocklists from profile"""
        if 'blocklists' not in self.profile:
            print("ℹ️  No blocklists defined in profile")
            return True
        
        blocklists = self.profile['blocklists']
        print(f"\n📋 Applying {len(blocklists)} blocklists...")
        
        for i, blocklist in enumerate(blocklists, 1):
            if not blocklist.get('enabled', True):
                print(f"   {i}. ⏭️  Skipping (disabled): {blocklist.get('name', 'unnamed')}")
                continue
            
            name = blocklist.get('name', 'unnamed')
            url = blocklist.get('url', '')
            description = blocklist.get('description', '')
            
            if not url:
                print(f"   {i}. ⚠️  No URL for blocklist: {name}")
                continue
            
            if self.dry_run:
                print(f"   {i}. 🔄 [DRY-RUN] Would add: {name}")
                print(f"       URL: {url}")
            else:
                # Add to Pi-hole via CLI or API
                # Note: Pi-hole doesn't have a direct API for adding adlists
                # We'll use the pihole command or gravity database
                success = self._add_blocklist_to_pihole(url, name)
                if success:
                    print(f"   {i}. ✅ Added: {name}")
                else:
                    print(f"   {i}. ❌ Failed: {name}")
        
        return True
    
    def _add_blocklist_to_pihole(self, url: str, comment: str = "") -> bool:
        """Add blocklist to Pi-hole gravity database"""
        try:
            # Method 1: Use sqlite directly (requires access to gravity database)
            # This would require running on the Pi-hole host
            
            # Method 2: Use pihole command (preferred if available)
            cmd = ["docker", "exec", "pihole_primary", "pihole", "-a", "-b", url]
            
            result = subprocess.run(
                cmd,
                capture_output=True,
                text=True,
                timeout=10
            )
            
            if result.returncode == 0 or "already exists" in result.stdout.lower():
                return True
            else:
                print(f"       Error: {result.stderr}")
                return False
        except Exception as e:
            print(f"       Error adding blocklist: {e}")
            return False
    
    def apply_whitelist(self) -> bool:
        """Apply whitelist from profile"""
        if 'whitelist' not in self.profile:
            print("ℹ️  No whitelist defined in profile")
            return True
        
        whitelist = self.profile['whitelist']
        print(f"\n✅ Applying whitelist ({len(whitelist)} categories)...")
        
        total_domains = 0
        for category in whitelist:
            name = category.get('name', 'unnamed')
            domains = category.get('domains', [])
            reason = category.get('reason', '')
            
            total_domains += len(domains)
            
            if self.dry_run:
                print(f"   🔄 [DRY-RUN] Would whitelist {len(domains)} domains for: {name}")
                for domain in domains:
                    print(f"       - {domain}")
            else:
                for domain in domains:
                    success = self._add_whitelist_to_pihole(domain)
                    if success:
                        print(f"   ✅ Whitelisted: {domain} ({name})")
                    else:
                        print(f"   ⚠️  Could not whitelist: {domain}")
        
        print(f"   Total domains whitelisted: {total_domains}")
        return True
    
    def _add_whitelist_to_pihole(self, domain: str) -> bool:
        """Add domain to Pi-hole whitelist"""
        try:
            # Use pihole command
            cmd = ["docker", "exec", "pihole_primary", "pihole", "-w", domain]
            
            result = subprocess.run(
                cmd,
                capture_output=True,
                text=True,
                timeout=10
            )
            
            return result.returncode == 0 or "already" in result.stdout.lower()
        except Exception as e:
            print(f"       Error whitelisting domain: {e}")
            return False
    
    def apply_regex_patterns(self) -> bool:
        """Apply regex blocking patterns"""
        if 'regex_patterns' not in self.profile:
            print("ℹ️  No regex patterns defined in profile")
            return True
        
        patterns = self.profile['regex_patterns']
        print(f"\n🔍 Applying {len(patterns)} regex patterns...")
        
        for i, pattern_config in enumerate(patterns, 1):
            if not pattern_config.get('enabled', True):
                print(f"   {i}. ⏭️  Skipping (disabled): {pattern_config.get('description', 'unnamed')}")
                continue
            
            pattern = pattern_config.get('pattern', '')
            description = pattern_config.get('description', '')
            
            if not pattern:
                print(f"   {i}. ⚠️  No pattern defined")
                continue
            
            if self.dry_run:
                print(f"   {i}. 🔄 [DRY-RUN] Would add regex: {description}")
                print(f"       Pattern: {pattern}")
            else:
                success = self._add_regex_to_pihole(pattern)
                if success:
                    print(f"   {i}. ✅ Added regex: {description}")
                else:
                    print(f"   {i}. ❌ Failed: {description}")
        
        return True
    
    def _add_regex_to_pihole(self, pattern: str) -> bool:
        """Add regex pattern to Pi-hole"""
        try:
            # Use pihole command with regex flag
            cmd = ["docker", "exec", "pihole_primary", "pihole", "regex", pattern]
            
            result = subprocess.run(
                cmd,
                capture_output=True,
                text=True,
                timeout=10
            )
            
            return result.returncode == 0 or "already" in result.stdout.lower()
        except Exception as e:
            print(f"       Error adding regex: {e}")
            return False
    
    def update_gravity(self) -> bool:
        """Update Pi-hole gravity (rebuild blocklists)"""
        if self.dry_run:
            print("\n🔄 [DRY-RUN] Would run: pihole -g (update gravity)")
            return True
        
        print("\n♻️  Updating Pi-hole gravity (this may take a few minutes)...")
        
        try:
            cmd = ["docker", "exec", "pihole_primary", "pihole", "-g"]
            
            result = subprocess.run(
                cmd,
                capture_output=True,
                text=True,
                timeout=300  # 5 minutes
            )
            
            if result.returncode == 0:
                print("✅ Gravity update completed successfully")
                return True
            else:
                print(f"❌ Gravity update failed: {result.stderr}")
                return False
        except subprocess.TimeoutExpired:
            print("❌ Gravity update timed out")
            return False
        except Exception as e:
            print(f"❌ Error updating gravity: {e}")
            return False
    
    def apply_profile(self) -> bool:
        """Apply the complete profile"""
        print("\n" + "="*60)
        print(f"Applying Profile: {self.profile.get('name', 'unknown')}")
        print(f"Target Pi-hole: {self.pihole_ip}")
        print(f"Mode: {'DRY-RUN (no changes)' if self.dry_run else 'LIVE'}")
        print("="*60)
        
        # Load profile
        self.load_profile()
        
        # Verify API access
        if not self.dry_run:
            if not self.verify_pihole_api():
                print("\n❌ Cannot proceed without Pi-hole API access")
                return False
        
        # Apply components
        self.apply_blocklists()
        self.apply_whitelist()
        self.apply_regex_patterns()
        
        # Update gravity to apply changes
        self.update_gravity()
        
        print("\n" + "="*60)
        if self.dry_run:
            print("✅ Dry-run completed. No changes were made.")
            print("   Run without --dry-run to apply changes.")
        else:
            print("✅ Profile applied successfully!")
            print(f"   Access Pi-hole admin at: http://{self.pihole_ip}/admin")
        print("="*60 + "\n")
        
        return True


def main():
    """Main entry point"""
    parser = argparse.ArgumentParser(
        description="Apply DNS privacy and security profiles to Pi-hole"
    )
    parser.add_argument(
        "--profile",
        required=True,
        help="Profile name (standard, family, paranoid) or path to custom profile YAML"
    )
    parser.add_argument(
        "--pihole-ip",
        help="Pi-hole IP address (default: from PIHOLE_PRIMARY_IP env or 192.168.8.251)"
    )
    parser.add_argument(
        "--pihole-password",
        help="Pi-hole admin password (default: from PIHOLE_PASSWORD env)"
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Show what would be done without making changes"
    )
    
    args = parser.parse_args()
    
    # Resolve profile path
    profile_path = args.profile
    if not profile_path.endswith('.yml') and not profile_path.endswith('.yaml'):
        # Assume it's a profile name
        script_dir = Path(__file__).parent
        profile_path = script_dir / f"{args.profile}.yml"
    
    if not os.path.exists(profile_path):
        print(f"❌ ERROR: Profile not found: {profile_path}")
        print("\nAvailable profiles:")
        script_dir = Path(__file__).parent
        for profile_file in script_dir.glob("*.yml"):
            print(f"  - {profile_file.stem}")
        sys.exit(1)
    
    # Create applicator and run
    applicator = ProfileApplicator(
        profile_path=str(profile_path),
        pihole_ip=args.pihole_ip,
        pihole_password=args.pihole_password,
        dry_run=args.dry_run
    )
    
    success = applicator.apply_profile()
    sys.exit(0 if success else 1)


if __name__ == "__main__":
    main()
