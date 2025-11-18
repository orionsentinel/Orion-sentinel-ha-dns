#!/bin/bash
###############################################################
# Authelia Secrets Generation Script
# Generates all required secrets for SSO stack
###############################################################

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SECRETS_DIR="${SCRIPT_DIR}/authelia/secrets"
ENV_FILE="${SCRIPT_DIR}/../../.env"

echo "=================================================="
echo "  Authelia Secrets Generation"
echo "=================================================="
echo ""

# Create secrets directory if it doesn't exist
mkdir -p "${SECRETS_DIR}"

# Function to generate random string
generate_secret() {
    openssl rand -base64 32 | tr -d '\n'
}

# Function to generate hex string
generate_hex() {
    openssl rand -hex 32 | tr -d '\n'
}

echo "Generating secrets..."
echo ""

# Generate JWT Secret
if [ ! -f "${SECRETS_DIR}/jwt_secret" ]; then
    echo "✓ Generating JWT secret..."
    generate_secret > "${SECRETS_DIR}/jwt_secret"
else
    echo "✓ JWT secret already exists (skipping)"
fi

# Generate Session Secret
if [ ! -f "${SECRETS_DIR}/session_secret" ]; then
    echo "✓ Generating session secret..."
    generate_secret > "${SECRETS_DIR}/session_secret"
else
    echo "✓ Session secret already exists (skipping)"
fi

# Generate Storage Encryption Key (must be at least 20 chars)
if [ ! -f "${SECRETS_DIR}/storage_encryption_key" ]; then
    echo "✓ Generating storage encryption key..."
    openssl rand -base64 48 | tr -d '\n' > "${SECRETS_DIR}/storage_encryption_key"
else
    echo "✓ Storage encryption key already exists (skipping)"
fi

# Generate OAuth2 Cookie Secret
OAUTH2_COOKIE_SECRET=$(python3 -c 'import os,base64; print(base64.urlsafe_b64encode(os.urandom(32)).decode())' 2>/dev/null || openssl rand -base64 32)

# Generate OAuth2 Client Secrets
OAUTH2_CLIENT_SECRET=$(generate_secret)
GRAFANA_OAUTH_SECRET=$(generate_secret)
PIHOLE_OAUTH_SECRET=$(generate_secret)
WIREGUARD_OAUTH_SECRET=$(generate_secret)

# Generate RSA private key for OIDC
if [ ! -f "${SECRETS_DIR}/oidc_private_key.pem" ]; then
    echo "✓ Generating RSA private key for OIDC..."
    openssl genrsa -out "${SECRETS_DIR}/oidc_private_key.pem" 4096 2>/dev/null
    chmod 600 "${SECRETS_DIR}/oidc_private_key.pem"
else
    echo "✓ RSA private key already exists (skipping)"
fi

# Generate HMAC secret for OIDC
OIDC_HMAC_SECRET=$(generate_hex)

# Set proper permissions
chmod 600 "${SECRETS_DIR}"/*
chmod 700 "${SECRETS_DIR}"

echo ""
echo "=================================================="
echo "  Secrets Generated Successfully!"
echo "=================================================="
echo ""
echo "The following secrets have been generated:"
echo "  - JWT Secret"
echo "  - Session Secret"
echo "  - Storage Encryption Key"
echo "  - OAuth2 Cookie Secret"
echo "  - OAuth2 Client Secrets"
echo "  - RSA Private Key for OIDC"
echo ""

# Update .env file or create .env.sso
ENV_SSO_FILE="${SCRIPT_DIR}/.env.sso"

cat > "${ENV_SSO_FILE}" << EOF
# SSO Stack Environment Variables
# Generated on $(date)

# OAuth2 Configuration
OAUTH2_COOKIE_SECRET=${OAUTH2_COOKIE_SECRET}
OAUTH2_CLIENT_ID=authelia
OAUTH2_CLIENT_SECRET=${OAUTH2_CLIENT_SECRET}

# OAuth2 Client Secrets for Services
GRAFANA_OAUTH_CLIENT_SECRET=${GRAFANA_OAUTH_SECRET}
PIHOLE_OAUTH_CLIENT_SECRET=${PIHOLE_OAUTH_SECRET}
WIREGUARD_OAUTH_CLIENT_SECRET=${WIREGUARD_OAUTH_SECRET}

# OIDC Configuration
OIDC_HMAC_SECRET=${OIDC_HMAC_SECRET}
EOF

chmod 600 "${ENV_SSO_FILE}"

echo "Environment variables saved to: ${ENV_SSO_FILE}"
echo ""
echo "To use these variables, add them to your main .env file:"
echo "  cat ${ENV_SSO_FILE} >> ${ENV_FILE}"
echo ""
echo "Or source them directly:"
echo "  source ${ENV_SSO_FILE}"
echo ""

# Generate admin password hash
echo "=================================================="
echo "  Admin User Setup"
echo "=================================================="
echo ""
echo "You need to set a password for the admin user."
echo ""
read -s -p "Enter admin password: " ADMIN_PASSWORD
echo ""
read -s -p "Confirm admin password: " ADMIN_PASSWORD_CONFIRM
echo ""

if [ "${ADMIN_PASSWORD}" != "${ADMIN_PASSWORD_CONFIRM}" ]; then
    echo "Error: Passwords do not match!"
    exit 1
fi

if [ ${#ADMIN_PASSWORD} -lt 12 ]; then
    echo "Error: Password must be at least 12 characters long!"
    exit 1
fi

echo "Generating password hash..."

# Generate password hash using Docker
ADMIN_PASSWORD_HASH=$(docker run --rm authelia/authelia:latest authelia crypto hash generate argon2 --password "${ADMIN_PASSWORD}" | grep '$argon2id$' || echo "")

if [ -z "${ADMIN_PASSWORD_HASH}" ]; then
    echo "Error: Failed to generate password hash. Is Docker installed and running?"
    exit 1
fi

# Update users_database.yml
sed -i.bak "s|password: \"\$argon2id\$[^\"]*\"|password: \"${ADMIN_PASSWORD_HASH}\"|" "${SCRIPT_DIR}/authelia/users_database.yml"
rm -f "${SCRIPT_DIR}/authelia/users_database.yml.bak"

echo ""
echo "✓ Admin password hash updated in users_database.yml"
echo ""

# Update configuration.yml with generated secrets
echo "Updating configuration.yml with generated secrets..."

# Read the RSA private key
RSA_KEY=$(cat "${SECRETS_DIR}/oidc_private_key.pem" | sed 's/^/      /')

# Create a temporary configuration file with secrets
cat > "${SCRIPT_DIR}/authelia/configuration.yml.tmp" << 'EOF'
---
###############################################################
#                   Authelia configuration                    #
###############################################################

server:
  host: 0.0.0.0
  port: 9091

log:
  level: info
  format: text

theme: light

totp:
  issuer: rpi-dns-stack
  period: 30

webauthn:
  disable: false
  display_name: RPi DNS Stack

access_control:
  default_policy: deny
  rules:
    - domain:
        - "*.local"
        - "192.168.8.250"
        - "192.168.8.251"
        - "192.168.8.252"
      policy: one_factor

session:
  name: authelia_session
  domain: 192.168.8.250
  same_site: lax
  expiration: 1h
  inactivity: 5m
  remember_me_duration: 1M
  redis:
    host: authelia-redis
    port: 6379

regulation:
  max_retries: 5
  find_time: 2m
  ban_time: 5m

storage:
  local:
    path: /config/db.sqlite3

notifier:
  filesystem:
    filename: /config/notification.txt

authentication_backend:
  file:
    path: /config/users_database.yml

identity_providers:
  oidc:
    hmac_secret: OIDC_HMAC_SECRET_PLACEHOLDER
    issuer_private_key: |
RSA_KEY_PLACEHOLDER
    access_token_lifespan: 1h
    authorize_code_lifespan: 1m
    id_token_lifespan: 1h
    refresh_token_lifespan: 90m
    
    clients:
      - id: grafana
        description: Grafana
        secret: '$plaintext$GRAFANA_SECRET_PLACEHOLDER'
        authorization_policy: one_factor
        redirect_uris:
          - http://192.168.8.250:3000/login/generic_oauth
        scopes:
          - openid
          - profile
          - email
          - groups
        
      - id: pihole
        description: Pi-hole
        secret: '$plaintext$PIHOLE_SECRET_PLACEHOLDER'
        authorization_policy: one_factor
        redirect_uris:
          - http://192.168.8.250:4180/oauth2/callback
        scopes:
          - openid
          - profile
          
      - id: wireguard-ui
        description: WireGuard-UI
        secret: '$plaintext$WIREGUARD_SECRET_PLACEHOLDER'
        authorization_policy: one_factor
        redirect_uris:
          - http://192.168.8.250:5000/oauth2/callback
        scopes:
          - openid
          - profile
EOF

# Replace placeholders
sed "s|OIDC_HMAC_SECRET_PLACEHOLDER|${OIDC_HMAC_SECRET}|" "${SCRIPT_DIR}/authelia/configuration.yml.tmp" | \
sed "s|GRAFANA_SECRET_PLACEHOLDER|${GRAFANA_OAUTH_SECRET}|" | \
sed "s|PIHOLE_SECRET_PLACEHOLDER|${PIHOLE_OAUTH_SECRET}|" | \
sed "s|WIREGUARD_SECRET_PLACEHOLDER|${WIREGUARD_OAUTH_SECRET}|" | \
sed "/RSA_KEY_PLACEHOLDER/r ${SECRETS_DIR}/oidc_private_key.pem" | \
sed "/RSA_KEY_PLACEHOLDER/d" > "${SCRIPT_DIR}/authelia/configuration.yml"

rm -f "${SCRIPT_DIR}/authelia/configuration.yml.tmp"

echo "✓ Configuration updated with secrets"
echo ""

echo "=================================================="
echo "  Setup Complete!"
echo "=================================================="
echo ""
echo "Next steps:"
echo "  1. Review the configuration in authelia/configuration.yml"
echo "  2. Add environment variables from .env.sso to your main .env file"
echo "  3. Start the SSO stack: docker compose up -d"
echo "  4. Access Authelia at: http://192.168.8.250:9091"
echo ""
echo "Default admin credentials:"
echo "  Username: admin"
echo "  Password: (the password you just set)"
echo ""
echo "IMPORTANT: Set up Two-Factor Authentication after first login!"
echo ""
