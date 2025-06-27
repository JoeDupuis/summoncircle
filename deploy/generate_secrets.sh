#!/usr/bin/env bash

# Script to generate Docker Compose secrets.env file
# Usage: ./generate_secrets.sh

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SECRETS_FILE="$SCRIPT_DIR/secrets.env"

echo "=== SummonCircle Secrets Generator ==="
echo

# Ask for admin credentials
echo "Admin User Setup:"
read -p "Admin email address [admin@example.com]: " ADMIN_EMAIL
ADMIN_EMAIL=${ADMIN_EMAIL:-admin@example.com}

read -sp "Admin password (press Enter to generate random): " ADMIN_PASSWORD
echo
if [ -z "$ADMIN_PASSWORD" ]; then
    ADMIN_PASSWORD=$(openssl rand -base64 12)
    echo "Generated password: $ADMIN_PASSWORD"
fi

# Ask if running locally or remotely
echo
echo "Deployment Type:"
echo "1) Local (localhost)"
echo "2) Remote (production domain)"
read -p "Select deployment type [1]: " DEPLOY_TYPE
DEPLOY_TYPE=${DEPLOY_TYPE:-1}

if [ "$DEPLOY_TYPE" = "2" ]; then
    read -p "Enter your domain (e.g., summoncircle.app): " DOMAIN
    while [ -z "$DOMAIN" ]; do
        echo "Domain is required for remote deployment"
        read -p "Enter your domain: " DOMAIN
    done
    TLS_DOMAIN=$DOMAIN
    RAILS_FORCE_SSL="true"
    RAILS_BINDING="0.0.0.0"
else
    DOMAIN="localhost"
    TLS_DOMAIN=""
    RAILS_FORCE_SSL="false"
    RAILS_BINDING="127.0.0.1"
fi

echo
echo "Generating secrets..."

# Generate encryption keys
echo "Generating Active Record encryption keys..."
PRIMARY_KEY=$(openssl rand -hex 32)
DETERMINISTIC_KEY=$(openssl rand -hex 32)
KEY_DERIVATION_SALT=$(openssl rand -hex 32)

# Generate auth token and secret key base
echo "Generating MCP auth token..."
MCP_AUTH_TOKEN=$(openssl rand -hex 64)

echo "Generating secret key base..."
SECRET_KEY_BASE=$(openssl rand -hex 64)

# Create secrets.env file for Docker Compose
cat > "$SECRETS_FILE" << EOF
ACTIVE_RECORD_ENCRYPTION_PRIMARY_KEY=$PRIMARY_KEY
ACTIVE_RECORD_ENCRYPTION_DETERMINISTIC_KEY=$DETERMINISTIC_KEY
ACTIVE_RECORD_ENCRYPTION_KEY_DERIVATION_SALT=$KEY_DERIVATION_SALT
SECRET_KEY_BASE=$SECRET_KEY_BASE
MCP_AUTH_TOKEN=$MCP_AUTH_TOKEN
SOLID_QUEUE_IN_PUMA=1
RAILS_ENV=production
RAILS_FORCE_SSL=$RAILS_FORCE_SSL
RAILS_BINDING=$RAILS_BINDING
ADMIN_EMAIL=$ADMIN_EMAIL
ADMIN_PASSWORD=$ADMIN_PASSWORD
TLS_DOMAIN=$TLS_DOMAIN
EOF

# Add container proxy settings for remote deployments
if [ "$DEPLOY_TYPE" = "2" ]; then
    cat >> "$SECRETS_FILE" << EOF
CONTAINER_PROXY_LINKS=1
CONTAINER_PROXY_TARGET_CONTAINERS=1
CONTAINER_PROXY_BASE_URL=$TLS_DOMAIN
EOF
fi

echo
echo "=== Configuration Summary ==="
echo "Admin Email: $ADMIN_EMAIL"
echo "Admin Password: $ADMIN_PASSWORD"
echo "Domain: $DOMAIN"
echo "Force SSL: $RAILS_FORCE_SSL"
if [ -n "$TLS_DOMAIN" ]; then
    echo "TLS Domain: $TLS_DOMAIN"
fi
echo
echo "Secrets file generated at: $SECRETS_FILE"
echo ""
if [ "$DEPLOY_TYPE" = "1" ]; then
    echo "You can now run: docker-compose up"
else
    echo "You can now run: docker-compose up -d"
fi