#!/usr/bin/env bash
# Start Moltbot with Proper Secrets Management
# Loads secrets from secure storage, starts Moltbot, then unsets secrets

set -euo pipefail

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}╔════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║  Moltbot Secure Startup                   ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════╝${NC}"
echo ""

# Check if running as root (not recommended)
if [ "$(id -u)" -eq 0 ]; then
    echo -e "${RED}Warning:${NC} Running as root is not recommended"
    echo "Consider running as a non-root user"
    echo ""
fi

# Secure permissions before starting
echo "Securing filesystem permissions..."
if [ -f "scripts/secure-permissions.sh" ]; then
    bash scripts/secure-permissions.sh
    echo ""
else
    echo -e "${YELLOW}⚠${NC} secure-permissions.sh not found, skipping permission check"
    echo ""
fi

# Load secrets from environment file if it exists
ENV_FILE="${HOME}/.moltbot/secrets.env"
if [ -f "$ENV_FILE" ]; then
    echo "Loading secrets from $ENV_FILE"
    # Source the file in a way that doesn't leak secrets to child processes
    set -a
    source "$ENV_FILE"
    set +a
    echo -e "${GREEN}✓${NC} Secrets loaded"
    echo ""
else
    echo -e "${YELLOW}⚠${NC} No secrets file found at $ENV_FILE"
    echo "Secrets must be provided via environment variables"
    echo ""
fi

# Verify required secrets are set
MISSING_SECRETS=0

check_secret() {
    local var_name="$1"
    local description="$2"
    
    if [ -z "${!var_name:-}" ]; then
        echo -e "${RED}✗${NC} Missing: $var_name ($description)"
        ((MISSING_SECRETS++)) || true
    else
        echo -e "${GREEN}✓${NC} Set: $var_name"
    fi
}

echo "Checking required secrets..."
check_secret "CLAWDBOT_GATEWAY_TOKEN" "Gateway authentication token"

# Check for at least one AI provider
if [ -n "${ANTHROPIC_API_KEY:-}" ] || [ -n "${OPENAI_API_KEY:-}" ] || [ -n "${GOOGLE_API_KEY:-}" ]; then
    echo -e "${GREEN}✓${NC} At least one AI provider API key is set"
else
    echo -e "${YELLOW}⚠${NC} No AI provider API keys found (ANTHROPIC_API_KEY, OPENAI_API_KEY, GOOGLE_API_KEY)"
    ((MISSING_SECRETS++)) || true
fi

echo ""

if [ $MISSING_SECRETS -gt 0 ]; then
    echo -e "${RED}Error:${NC} Missing $MISSING_SECRETS required secret(s)"
    echo ""
    echo "To set up secrets, create $ENV_FILE with:"
    echo ""
    echo "  # Gateway authentication"
    echo "  export CLAWDBOT_GATEWAY_TOKEN=your_token_here"
    echo ""
    echo "  # AI Provider (at least one required)"
    echo "  export ANTHROPIC_API_KEY=your_anthropic_key"
    echo "  # or"
    echo "  export OPENAI_API_KEY=your_openai_key"
    echo "  # or"
    echo "  export GOOGLE_API_KEY=your_google_key"
    echo ""
    echo "Then run: chmod 600 $ENV_FILE"
    echo ""
    exit 1
fi

# Start Moltbot based on deployment method
echo -e "${BLUE}Starting Moltbot...${NC}"
echo ""

if [ -f "docker-compose.yml" ]; then
    echo "Using Docker Compose..."
    docker compose up -d
    echo ""
    echo -e "${GREEN}✓${NC} Moltbot gateway started"
    echo ""
    echo "Check status:"
    echo "  docker compose ps"
    echo "  docker compose logs -f moltbot-gateway"
    echo ""
    echo "Access web UI:"
    echo "  http://localhost:18789/?token=\$CLAWDBOT_GATEWAY_TOKEN"
    echo ""
elif command -v moltbot &> /dev/null; then
    echo "Using moltbot CLI..."
    echo "Starting gateway in background..."
    nohup moltbot gateway --bind loopback --port 18789 > /tmp/moltbot-gateway.log 2>&1 &
    GATEWAY_PID=$!
    echo -e "${GREEN}✓${NC} Moltbot gateway started (PID: $GATEWAY_PID)"
    echo ""
    echo "Check status:"
    echo "  tail -f /tmp/moltbot-gateway.log"
    echo "  moltbot channels status"
    echo ""
else
    echo -e "${RED}Error:${NC} Cannot find moltbot or docker-compose"
    echo "Please install Moltbot first"
    exit 1
fi

# Security reminder
echo -e "${YELLOW}Security Reminders:${NC}"
echo "  • Secrets are loaded only for this process"
echo "  • Gateway binds to localhost only (127.0.0.1)"
echo "  • Token authentication is required"
echo "  • Rotate tokens regularly with: bash scripts/rotate-gateway-token.sh"
echo "  • Run security audit: bash scripts/security-audit.sh"
echo ""

# Unset secrets from current shell (they're already passed to docker/moltbot)
# This prevents them from being visible in 'env' or leaked to other processes
if [ -n "${ANTHROPIC_API_KEY:-}" ]; then unset ANTHROPIC_API_KEY; fi
if [ -n "${OPENAI_API_KEY:-}" ]; then unset OPENAI_API_KEY; fi
if [ -n "${GOOGLE_API_KEY:-}" ]; then unset GOOGLE_API_KEY; fi
if [ -n "${CLAUDE_AI_SESSION_KEY:-}" ]; then unset CLAUDE_AI_SESSION_KEY; fi
if [ -n "${CLAUDE_WEB_SESSION_KEY:-}" ]; then unset CLAUDE_WEB_SESSION_KEY; fi
if [ -n "${CLAUDE_WEB_COOKIE:-}" ]; then unset CLAUDE_WEB_COOKIE; fi

echo -e "${GREEN}✓${NC} Secrets unset from current shell"
echo ""
