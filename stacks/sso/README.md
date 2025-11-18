# SSO Stack - Single Sign-On with Authelia

This stack provides centralized authentication and Single Sign-On (SSO) for all services in the RPi HA DNS Stack.

## Features

- **Single Sign-On**: Log in once, access all services
- **Two-Factor Authentication**: TOTP (Google Authenticator, Authy) and WebAuthn (YubiKey, TouchID)
- **Session Management**: Centralized session control with Redis
- **Brute Force Protection**: Automatic rate limiting and banning
- **OAuth2/OIDC Provider**: Standards-based authentication for modern applications
- **Fine-grained Access Control**: Configure access rules per service
- **Lightweight**: Runs efficiently on Raspberry Pi

## Architecture

```
┌─────────────┐
│   Browser   │
└──────┬──────┘
       │
       ├─────────────┐
       │             │
┌──────▼──────┐  ┌──▼─────────────┐
│  Authelia   │  │  OAuth2 Proxy  │
│  (Port 9091)│  │  (Port 4180)   │
└──────┬──────┘  └────────────────┘
       │
┌──────▼──────────────────────┐
│                              │
│  Protected Services:         │
│  - Pi-hole (251/252)         │
│  - Grafana (3000)            │
│  - WireGuard-UI (5000)       │
│  - Nginx Proxy Manager (81)  │
│  - Prometheus (9090)         │
│  - Alertmanager (9093)       │
│                              │
└──────────────────────────────┘
```

## Quick Start

### 1. Generate Secrets

Before starting, you need to generate secure secrets:

```bash
# Navigate to SSO directory
cd stacks/sso

# Generate secrets using the provided script
bash generate-secrets.sh
```

This will create:
- JWT secret for token signing
- Session secret for session encryption
- Storage encryption key
- OAuth2 cookie secret
- RSA private key for OIDC

### 2. Configure Users

Edit `authelia/users_database.yml` to add users:

```bash
# Generate password hash
docker run --rm authelia/authelia:latest authelia crypto hash generate argon2 --password 'your_password'

# Add the hash to users_database.yml
```

Example user:
```yaml
users:
  admin:
    displayname: "Admin User"
    password: "$argon2id$v=19$m=65536,t=1,p=8$..."
    email: admin@example.com
    groups:
      - admins
      - users
```

### 3. Configure Environment Variables

Add to your `.env` file:

```bash
# SSO Configuration
AUTHELIA_JWT_SECRET=your_generated_jwt_secret
AUTHELIA_SESSION_SECRET=your_generated_session_secret
AUTHELIA_STORAGE_ENCRYPTION_KEY=your_generated_encryption_key
OAUTH2_COOKIE_SECRET=your_generated_cookie_secret
OAUTH2_CLIENT_SECRET=your_oauth2_client_secret

# OAuth2 Client Secrets for each service
GRAFANA_OAUTH_CLIENT_SECRET=grafana_client_secret_change_me
PIHOLE_OAUTH_CLIENT_SECRET=pihole_client_secret_change_me
WIREGUARD_OAUTH_CLIENT_SECRET=wireguard_client_secret_change_me
```

### 4. Start the SSO Stack

```bash
cd stacks/sso
docker compose up -d
```

### 5. Access Authelia Portal

Open your browser and navigate to:
- **Authelia Portal**: http://192.168.8.250:9091

First login:
- Username: `admin`
- Password: (the password you set in users_database.yml)

### 6. Set Up Two-Factor Authentication (Recommended)

1. Log in to Authelia portal
2. Go to Settings → Two-Factor Authentication
3. Scan QR code with your authenticator app (Google Authenticator, Authy, etc.)
4. Enter the 6-digit code to confirm

## Integrating Services with SSO

### Grafana Integration

Grafana supports native OAuth2/OIDC integration with Authelia.

**Configure in `stacks/observability/docker-compose.yml`:**

```yaml
grafana:
  environment:
    # Enable OAuth2
    - GF_AUTH_GENERIC_OAUTH_ENABLED=true
    - GF_AUTH_GENERIC_OAUTH_NAME=Authelia
    - GF_AUTH_GENERIC_OAUTH_CLIENT_ID=grafana
    - GF_AUTH_GENERIC_OAUTH_CLIENT_SECRET=${GRAFANA_OAUTH_CLIENT_SECRET}
    - GF_AUTH_GENERIC_OAUTH_SCOPES=openid profile email groups
    - GF_AUTH_GENERIC_OAUTH_AUTH_URL=http://192.168.8.250:9091/api/oidc/authorization
    - GF_AUTH_GENERIC_OAUTH_TOKEN_URL=http://authelia:9091/api/oidc/token
    - GF_AUTH_GENERIC_OAUTH_API_URL=http://authelia:9091/api/oidc/userinfo
    - GF_AUTH_GENERIC_OAUTH_ROLE_ATTRIBUTE_PATH=contains(groups[*], 'admins') && 'Admin' || 'Viewer'
```

### Pi-hole Integration (via OAuth2 Proxy)

Pi-hole doesn't natively support OAuth2, so we use OAuth2 Proxy as a middleware.

**Access Pi-hole through OAuth2 Proxy:**
- URL: http://192.168.8.250:4180/pihole1 (proxies to 192.168.8.251)
- URL: http://192.168.8.250:4180/pihole2 (proxies to 192.168.8.252)

### WireGuard-UI Integration

Configure WireGuard-UI to use external authentication:

```yaml
wireguard-ui:
  environment:
    - WGUI_EXTERNAL_AUTH=true
    - WGUI_AUTH_URL=http://192.168.8.250:9091/api/verify?rd=http://192.168.8.250:5000
```

## Access Control Rules

Edit `authelia/configuration.yml` to configure access rules:

```yaml
access_control:
  rules:
    # Admin-only services
    - domain:
        - "192.168.8.250"
      resources:
        - "^/api/admin/.*$"
      policy: two_factor
      subject:
        - "group:admins"
    
    # All authenticated users
    - domain:
        - "192.168.8.250"
        - "192.168.8.251"
        - "192.168.8.252"
      policy: one_factor
```

## Management Commands

```bash
# Start SSO stack
docker compose up -d

# Stop SSO stack
docker compose down

# View logs
docker compose logs -f authelia
docker compose logs -f oauth2-proxy

# Restart Authelia
docker compose restart authelia

# Check Authelia health
curl http://192.168.8.250:9091/api/health
```

## Security Best Practices

1. **Strong Passwords**: Use passwords with at least 16 characters
2. **Enable 2FA**: Always enable two-factor authentication
3. **Regular Updates**: Keep Authelia and OAuth2 Proxy updated
4. **Secure Secrets**: Use the generate-secrets.sh script, never hardcode secrets
5. **HTTPS**: In production, use HTTPS with valid certificates (via Nginx Proxy Manager)
6. **Regular Audits**: Review access logs regularly
7. **Least Privilege**: Give users only necessary permissions

## Troubleshooting

### Cannot access Authelia portal

```bash
# Check if container is running
docker ps | grep authelia

# Check logs for errors
docker logs authelia

# Verify port is accessible
curl http://192.168.8.250:9091/api/health
```

### Login fails with "Invalid credentials"

1. Verify user exists in `authelia/users_database.yml`
2. Check password hash is correct
3. Review logs: `docker logs authelia`

### Service not redirecting to Authelia

1. Verify OAuth2 client configuration in `authelia/configuration.yml`
2. Check redirect URLs match exactly
3. Ensure service is configured to use Authelia

### 2FA setup fails

1. Ensure time is synchronized on Pi (NTP)
2. Try manual entry instead of QR code
3. Check authenticator app settings

### Redis connection errors

```bash
# Check Redis is running
docker ps | grep redis

# Test Redis connection
docker exec authelia-redis redis-cli ping
```

## Backup and Recovery

### Backup Important Files

```bash
# Backup Authelia database and configuration
tar -czf authelia-backup-$(date +%Y%m%d).tar.gz \
  stacks/sso/authelia/db.sqlite3 \
  stacks/sso/authelia/users_database.yml \
  stacks/sso/authelia/secrets/
```

### Restore from Backup

```bash
# Stop Authelia
docker compose down

# Extract backup
tar -xzf authelia-backup-YYYYMMDD.tar.gz

# Restart Authelia
docker compose up -d
```

## Advanced Configuration

### SMTP Notifications

Replace file-based notifier with SMTP:

```yaml
notifier:
  disable_startup_check: false
  smtp:
    username: your-email@gmail.com
    password: your-app-password
    host: smtp.gmail.com
    port: 587
    sender: authelia@rpi-dns-stack.local
    startup_check_address: test@authelia.com
```

### LDAP Backend

For larger deployments, use LDAP instead of file-based users:

```yaml
authentication_backend:
  ldap:
    url: ldap://openldap:389
    base_dn: dc=example,dc=com
    username_attribute: uid
    additional_users_dn: ou=users
    users_filter: (&({username_attribute}={input})(objectClass=person))
    additional_groups_dn: ou=groups
    groups_filter: (&(member={dn})(objectClass=groupOfNames))
```

## Performance Tuning

For Raspberry Pi optimization:

```yaml
storage:
  local:
    path: /config/db.sqlite3
  
session:
  redis:
    # Adjust based on memory availability
    maximum_active_connections: 8
    minimum_idle_connections: 0
```

## Resources

- [Authelia Documentation](https://www.authelia.com/)
- [OAuth2 Proxy Documentation](https://oauth2-proxy.github.io/oauth2-proxy/)
- [OpenID Connect Specification](https://openid.net/connect/)

## License

Part of the RPi HA DNS Stack project.
