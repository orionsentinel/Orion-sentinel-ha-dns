# SSO Integration Guide

This guide explains how to integrate SSO (Single Sign-On) with your existing services in the RPi HA DNS Stack.

## Overview

The SSO stack uses Authelia as the authentication provider and OAuth2 Proxy as middleware for services that don't natively support OAuth2/OIDC.

## Prerequisites

1. Main stack already deployed and running
2. SSO stack deployed (see `stacks/sso/README.md`)
3. `.env` file configured with SSO variables

## Service Integration Status

| Service | Port | Integration Method | Status |
|---------|------|-------------------|--------|
| Grafana | 3000 | Native OAuth2 | ✅ Ready |
| Pi-hole | 251/252 | OAuth2 Proxy | 🔧 Manual |
| WireGuard-UI | 5000 | OAuth2 Proxy | 🔧 Manual |
| Nginx Proxy Manager | 81 | OAuth2 Proxy | 🔧 Manual |
| Prometheus | 9090 | OAuth2 Proxy | 🔧 Optional |
| Alertmanager | 9093 | OAuth2 Proxy | 🔧 Optional |

## ✅ Grafana - Native OAuth2 Integration

Grafana has native OAuth2/OIDC support and is already configured when SSO is enabled.

**Configuration (already in docker-compose.yml):**
```yaml
environment:
  - GF_AUTH_GENERIC_OAUTH_ENABLED=${SSO_ENABLED:-false}
  - GF_AUTH_GENERIC_OAUTH_NAME=Authelia
  - GF_AUTH_GENERIC_OAUTH_CLIENT_ID=grafana
  - GF_AUTH_GENERIC_OAUTH_CLIENT_SECRET=${GRAFANA_OAUTH_CLIENT_SECRET}
```

**How to Use:**
1. Navigate to http://192.168.8.250:3000
2. Click "Sign in with Authelia"
3. Log in with your Authelia credentials
4. Complete 2FA if enabled

**Permissions:**
- Users in `admins` group → Grafana Admin role
- All other users → Grafana Viewer role

## 🔧 Pi-hole - OAuth2 Proxy Integration

Pi-hole doesn't support OAuth2, so we use OAuth2 Proxy as middleware.

### Option 1: Direct OAuth2 Proxy (Recommended for Testing)

**1. Update OAuth2 Proxy Configuration**

Edit `stacks/sso/docker-compose.yml`:

```yaml
oauth2-proxy:
  command:
    - --http-address=0.0.0.0:4180
    - --provider=oidc
    - --oidc-issuer-url=http://authelia:9091
    - --redirect-url=http://${HOST_IP}:4180/oauth2/callback
    - --cookie-secret=${OAUTH2_COOKIE_SECRET}
    - --cookie-domain=${HOST_IP}
    - --email-domain=*
    # Add upstream for Pi-hole
    - --upstream=http://192.168.8.251/admin/
    - --upstream=http://192.168.8.252/admin/
```

**2. Access Pi-hole through Proxy**

- Primary Pi-hole: http://192.168.8.250:4180
- You'll be redirected to Authelia for login

### Option 2: Nginx Reverse Proxy with Authelia (Production)

**1. Install Nginx (if not using Nginx Proxy Manager)**

```bash
sudo apt update && sudo apt install nginx -y
```

**2. Create Nginx Configuration**

Create `/etc/nginx/sites-available/pihole-sso`:

```nginx
server {
    listen 8080;
    server_name _;

    location / {
        # Forward auth to Authelia
        auth_request /authelia/api/verify;
        auth_request_set $user $upstream_http_remote_user;
        auth_request_set $groups $upstream_http_remote_groups;
        auth_request_set $name $upstream_http_remote_name;
        auth_request_set $email $upstream_http_remote_email;
        
        # Redirect to Authelia if not authenticated
        error_page 401 =302 http://192.168.8.250:9091/?rd=$scheme://$http_host$request_uri;

        # Pass to Pi-hole
        proxy_pass http://192.168.8.251/admin/;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        
        # Pass user info to Pi-hole
        proxy_set_header Remote-User $user;
        proxy_set_header Remote-Groups $groups;
        proxy_set_header Remote-Name $name;
        proxy_set_header Remote-Email $email;
    }

    # Authelia auth endpoint
    location /authelia {
        internal;
        proxy_pass http://192.168.8.250:9091;
        proxy_set_header Content-Length "";
        proxy_pass_request_body off;
    }
}
```

**3. Enable and Restart Nginx**

```bash
sudo ln -s /etc/nginx/sites-available/pihole-sso /etc/nginx/sites-enabled/
sudo nginx -t
sudo systemctl reload nginx
```

**4. Access Pi-hole**

- With SSO: http://192.168.8.250:8080
- Original (bypass SSO): http://192.168.8.251/admin

## 🔧 WireGuard-UI Integration

WireGuard-UI can work with external authentication.

**Update `stacks/vpn/docker-compose.yml`:**

```yaml
wireguard-ui:
  environment:
    # Existing vars...
    - WGUI_EXTERNAL_AUTH=true
    - WGUI_AUTH_URL=http://192.168.8.250:9091/api/verify
    - WGUI_LOGOUT_URL=http://192.168.8.250:9091/logout
```

**Restart WireGuard-UI:**

```bash
cd stacks/vpn
docker compose restart wireguard-ui
```

## 🔧 Nginx Proxy Manager Integration

Nginx Proxy Manager can be protected using OAuth2 Proxy or Authelia forward auth.

**Using OAuth2 Proxy:**

1. Update OAuth2 Proxy to include NPM upstream
2. Access at http://192.168.8.250:4180/npm

**Using Authelia with Nginx:**

Similar to Pi-hole integration above, create reverse proxy config for port 81.

## Testing SSO Integration

### 1. Test Authelia

```bash
curl http://192.168.8.250:9091/api/health
# Should return: {"status":"UP"}
```

### 2. Test Grafana OAuth

1. Open http://192.168.8.250:3000
2. You should see "Sign in with Authelia" button
3. Click it and verify redirect to Authelia

### 3. Test OAuth2 Proxy

```bash
curl -I http://192.168.8.250:4180
# Should return 302 redirect to Authelia
```

## Troubleshooting

### "Invalid redirect URI" Error

**Cause:** OAuth client redirect URL doesn't match configured URL

**Fix:** Update `stacks/sso/authelia/configuration.yml`:

```yaml
clients:
  - id: grafana
    redirect_uris:
      - http://192.168.8.250:3000/login/generic_oauth
      - http://YOUR_ACTUAL_IP:3000/login/generic_oauth
```

### Login Loop (Keeps Redirecting)

**Cause:** Cookie domain mismatch

**Fix:** Ensure `cookie-domain` in OAuth2 Proxy matches your HOST_IP:

```yaml
- --cookie-domain=${HOST_IP}
```

### "Failed to get user info" in Grafana

**Cause:** Authelia OIDC endpoint not accessible from Grafana container

**Fix:** Ensure services are on same network:

```yaml
networks:
  - sso_net
```

### 2FA Not Working

**Cause:** Time drift between server and TOTP device

**Fix:**
```bash
# Check system time
date

# Sync time
sudo timedatectl set-ntp true
sudo systemctl restart systemd-timesyncd
```

## Advanced Configuration

### Custom Access Rules

Edit `stacks/sso/authelia/configuration.yml`:

```yaml
access_control:
  rules:
    # Require 2FA for admin services
    - domain:
        - "192.168.8.250"
      resources:
        - "^/admin/.*$"
      policy: two_factor
      subject:
        - "group:admins"
    
    # Allow authenticated users for monitoring
    - domain:
        - "192.168.8.250"
      resources:
        - "^/(grafana|prometheus)/.*$"
      policy: one_factor
```

### LDAP Backend

For larger deployments, use LDAP instead of file-based authentication:

```yaml
authentication_backend:
  ldap:
    url: ldap://openldap:389
    base_dn: dc=example,dc=com
    username_attribute: uid
    additional_users_dn: ou=users
    users_filter: (&({username_attribute}={input})(objectClass=person))
    groups_filter: (&(member={dn})(objectClass=groupOfNames))
```

### Session Duration

Adjust session timeout in `stacks/sso/authelia/configuration.yml`:

```yaml
session:
  expiration: 12h  # How long before session expires
  inactivity: 1h   # How long before inactive logout
  remember_me_duration: 30d  # "Remember me" duration
```

## Security Best Practices

1. **Always Enable 2FA**: Require two-factor authentication for admin access
2. **Use HTTPS**: In production, configure SSL/TLS certificates
3. **Regular Updates**: Keep Authelia and OAuth2 Proxy updated
4. **Strong Passwords**: Enforce minimum 16 character passwords
5. **Audit Logs**: Regularly review Authelia logs for suspicious activity
6. **Least Privilege**: Give users minimum necessary permissions
7. **Secrets Management**: Never commit secrets to git

## Monitoring SSO

### View Authelia Logs

```bash
docker logs -f authelia
```

### Check Active Sessions

View Redis sessions:

```bash
docker exec authelia-redis redis-cli KEYS "authelia:*"
```

### Failed Login Attempts

Check for brute force attempts:

```bash
docker logs authelia | grep "authentication failed"
```

## Backup SSO Configuration

```bash
# Backup Authelia data
tar -czf authelia-backup-$(date +%Y%m%d).tar.gz \
  stacks/sso/authelia/db.sqlite3 \
  stacks/sso/authelia/users_database.yml \
  stacks/sso/authelia/secrets/
```

## Resources

- [Authelia Documentation](https://www.authelia.com/docs/)
- [OAuth2 Proxy Documentation](https://oauth2-proxy.github.io/oauth2-proxy/)
- [Grafana OAuth Configuration](https://grafana.com/docs/grafana/latest/setup-grafana/configure-security/configure-authentication/generic-oauth/)
- [OIDC Specification](https://openid.net/specs/openid-connect-core-1_0.html)

## Need Help?

- Check the main troubleshooting guide: `stacks/sso/README.md`
- Review Authelia logs: `docker logs authelia`
- Open an issue on GitHub with relevant logs

## Next Steps

After setting up SSO:

1. **Enable 2FA**: Set up TOTP on your account
2. **Add Users**: Create accounts for team members
3. **Configure Roles**: Set up appropriate access groups
4. **Test Failover**: Verify services work if Authelia is down
5. **Monitor**: Set up alerts for failed authentication attempts
