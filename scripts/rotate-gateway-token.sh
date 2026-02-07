#!/usr/bin/env bash
# Gateway Token Rotation Script for Moltbot
# Generates and updates the gateway authentication token

set -euo pipefail

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Determine the Moltbot directory
if [ -d "${HOME}/.moltbot" ]; then
    MOLTBOT_DIR="${HOME}/.moltbot"
elif [ -d "${HOME}/.clawdbot" ]; then
    MOLTBOT_DIR="${HOME}/.clawdbot"
else
    echo -e "${RED}Error:${NC} Moltbot directory not found"
    echo "Expected: ~/.moltbot or ~/.clawdbot"
    echo "Please run 'mkdir -p ~/.moltbot' first"
    exit 1
fi

CONFIG_FILE="${MOLTBOT_DIR}/moltbot.json"
if [ ! -f "$CONFIG_FILE" ]; then
    # Try alternative names
    for alt_name in "openclaw.json" "clawdbot.json"; do
        if [ -f "${MOLTBOT_DIR}/${alt_name}" ]; then
            CONFIG_FILE="${MOLTBOT_DIR}/${alt_name}"
            break
        fi
    done
fi

echo -e "${BLUE}╔════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║  Moltbot Gateway Token Rotation           ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════╝${NC}"
echo ""

# Generate a secure random token (32 bytes = 64 hex characters)
echo "Generating new token..."
if command -v openssl &> /dev/null; then
    NEW_TOKEN=$(openssl rand -hex 32)
elif command -v /dev/urandom &> /dev/null; then
    NEW_TOKEN=$(head -c 32 /dev/urandom | xxd -p -c 64)
else
    echo -e "${RED}Error:${NC} Cannot generate secure random token"
    echo "Neither openssl nor /dev/urandom is available"
    exit 1
fi

echo -e "${GREEN}✓${NC} Generated new token: ${NEW_TOKEN:0:16}... (truncated for display)"
echo ""

# Check if config file exists
if [ ! -f "$CONFIG_FILE" ]; then
    echo "Creating new configuration file..."
    cat > "$CONFIG_FILE" << EOF
{
  "gateway": {
    "auth": {
      "mode": "token",
      "token": "$NEW_TOKEN"
    },
    "bind": "loopback",
    "port": 18789
  }
}
EOF
    chmod 600 "$CONFIG_FILE"
    echo -e "${GREEN}✓${NC} Created $CONFIG_FILE with token authentication"
else
    echo "Updating existing configuration..."
    
    # Check if jq is available for JSON manipulation
    if command -v jq &> /dev/null; then
        # Backup the original file
        cp "$CONFIG_FILE" "${CONFIG_FILE}.backup"
        echo -e "${YELLOW}ℹ${NC} Backup created: ${CONFIG_FILE}.backup"
        
        # Update the token using jq
        jq --arg token "$NEW_TOKEN" \
           '.gateway.auth.mode = "token" | .gateway.auth.token = $token' \
           "$CONFIG_FILE" > "${CONFIG_FILE}.tmp" && mv "${CONFIG_FILE}.tmp" "$CONFIG_FILE"
        
        chmod 600 "$CONFIG_FILE"
        echo -e "${GREEN}✓${NC} Updated $CONFIG_FILE with new token"
    else
        echo -e "${YELLOW}⚠${NC} jq not available, manual update required"
        echo ""
        echo "Please add the following to your $CONFIG_FILE:"
        echo ""
        echo '{'
        echo '  "gateway": {'
        echo '    "auth": {'
        echo '      "mode": "token",'
        echo "      \"token\": \"$NEW_TOKEN\""
        echo '    }'
        echo '  }'
        echo '}'
        echo ""
        echo "New token: $NEW_TOKEN"
        exit 1
    fi
fi

# Secure permissions
chmod 600 "$CONFIG_FILE"
echo -e "${GREEN}✓${NC} Secured config file permissions (600)"
echo ""

echo -e "${BLUE}═══════════════════════════════════════════${NC}"
echo "Token rotation complete!"
echo ""
echo "IMPORTANT: Save this token securely. You will need it to:"
echo "  - Access the gateway web UI"
echo "  - Connect clients to the gateway"
echo "  - Make API calls to the gateway"
echo ""
echo -e "Token: ${YELLOW}${NEW_TOKEN}${NC}"
echo ""
echo "To use the token:"
echo "  - Web UI: Add ?token=$NEW_TOKEN to the URL"
echo "  - CLI: Set CLAWDBOT_GATEWAY_TOKEN=$NEW_TOKEN"
echo "  - Docker: Set CLAWDBOT_GATEWAY_TOKEN in docker-compose.yml"
echo ""
echo "Restart the gateway for changes to take effect:"
echo "  docker compose restart moltbot-gateway"
echo ""
