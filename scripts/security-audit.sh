#!/usr/bin/env bash
# Comprehensive Security Audit for Moltbot
# Performs thorough security checks including live probes

set -euo pipefail

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

CHECKS_PASSED=0
CHECKS_FAILED=0
CHECKS_WARNED=0

check_pass() {
    echo -e "${GREEN}✓${NC} $1"
    ((CHECKS_PASSED++)) || true
}

check_fail() {
    echo -e "${RED}✗${NC} $1"
    ((CHECKS_FAILED++)) || true
}

check_warn() {
    echo -e "${YELLOW}⚠${NC} $1"
    ((CHECKS_WARNED++)) || true
}

section() {
    echo ""
    echo -e "${BLUE}=== $1 ===${NC}"
}

echo -e "${BLUE}╔════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║  Moltbot Comprehensive Security Audit     ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════╝${NC}"

# Section 1: Docker Configuration
section "Docker Configuration Audit"

echo "Checking Docker socket exposure..."
if grep -r "/var/run/docker.sock" docker-compose*.yml 2>/dev/null | grep -v "^#"; then
    check_fail "Docker socket is mounted (allows container escape)"
else
    check_pass "No Docker socket mount found in compose files"
fi

echo "Checking port bindings..."
if [ -f "docker-compose.override.yml" ]; then
    if grep -q "127.0.0.1:18789" docker-compose.override.yml 2>/dev/null; then
        check_pass "Gateway port (18789) is bound to localhost"
    else
        check_fail "Gateway port may be exposed to network"
    fi
    
    if grep -q "127.0.0.1:18790" docker-compose.override.yml 2>/dev/null; then
        check_pass "Bridge port (18790) is bound to localhost"
    else
        check_warn "Bridge port binding not configured"
    fi
else
    check_warn "docker-compose.override.yml not found (create it to enforce localhost binding)"
fi

echo "Checking bind mode configuration..."
if grep -r "loopback" docker-compose*.yml 2>/dev/null | grep -v "^#"; then
    check_pass "Loopback bind mode is configured in compose files"
else
    check_warn "Bind mode is not explicitly set to loopback"
fi

echo "Checking container user configuration..."
if grep -q "^USER node" Dockerfile 2>/dev/null; then
    check_pass "Dockerfile uses non-root user (node)"
else
    check_fail "Dockerfile does not specify non-root user"
fi

# Section 2: Filesystem Permissions
section "Filesystem Permissions Audit"

MOLTBOT_DIR="${HOME}/.moltbot"
CRED_DIR="${MOLTBOT_DIR}/credentials"
CONFIG_FILE="${MOLTBOT_DIR}/moltbot.json"

echo "Checking Moltbot directory..."
if [ -d "$MOLTBOT_DIR" ]; then
    check_pass "Moltbot directory exists: $MOLTBOT_DIR"
    
    echo "Checking credentials directory..."
    if [ -d "$CRED_DIR" ]; then
        PERMS=$(stat -c %a "$CRED_DIR" 2>/dev/null || stat -f %A "$CRED_DIR" 2>/dev/null || echo "unknown")
        if [ "$PERMS" = "700" ]; then
            check_pass "Credentials directory has secure permissions (700)"
        else
            check_fail "Credentials directory has insecure permissions: $PERMS (should be 700)"
        fi
    else
        check_warn "Credentials directory does not exist yet"
    fi
    
    echo "Checking config file..."
    if [ -f "$CONFIG_FILE" ]; then
        PERMS=$(stat -c %a "$CONFIG_FILE" 2>/dev/null || stat -f %A "$CONFIG_FILE" 2>/dev/null || echo "unknown")
        if [ "$PERMS" = "600" ]; then
            check_pass "Config file has secure permissions (600)"
        else
            check_fail "Config file has insecure permissions: $PERMS (should be 600)"
        fi
    else
        check_warn "Config file does not exist yet"
    fi
    
    echo "Checking for auth profiles..."
    while IFS= read -r profile; do
        if [ -n "$profile" ]; then
            PERMS=$(stat -c %a "$profile" 2>/dev/null || stat -f %A "$profile" 2>/dev/null || echo "unknown")
            if [ "$PERMS" = "600" ]; then
                check_pass "Auth profile has secure permissions: $(basename "$(dirname "$profile")")"
            else
                check_fail "Auth profile has insecure permissions $PERMS: $(basename "$(dirname "$profile")")"
            fi
        fi
    done < <(find "$MOLTBOT_DIR" -name "auth-profiles.json" 2>/dev/null || true)
else
    check_warn "Moltbot directory does not exist yet: $MOLTBOT_DIR"
fi

# Section 3: Configuration Analysis
section "Configuration Analysis"

if [ -f "$CONFIG_FILE" ]; then
    echo "Checking gateway authentication..."
    if command -v jq &> /dev/null && [ -f "$CONFIG_FILE" ]; then
        AUTH_MODE=$(jq -r '.gateway.auth.mode // "none"' "$CONFIG_FILE" 2>/dev/null || echo "none")
        if [ "$AUTH_MODE" = "token" ]; then
            check_pass "Gateway token authentication is enabled"
        elif [ "$AUTH_MODE" = "none" ]; then
            check_warn "Gateway authentication is disabled (consider enabling token auth)"
        else
            check_pass "Gateway authentication is enabled (mode: $AUTH_MODE)"
        fi
    else
        check_warn "Cannot parse config file (jq not available)"
    fi
    
    echo "Checking logging configuration..."
    if command -v jq &> /dev/null && [ -f "$CONFIG_FILE" ]; then
        REDACT=$(jq -r '.logging.redactSensitive // "none"' "$CONFIG_FILE" 2>/dev/null || echo "none")
        if [ "$REDACT" != "none" ]; then
            check_pass "Log redaction is enabled: $REDACT"
        else
            check_warn "Log redaction is not configured"
        fi
    fi
fi

# Section 4: Runtime Checks
section "Runtime Security Checks"

if docker compose ps 2>/dev/null | grep -q "moltbot-gateway"; then
    echo "Checking running container..."
    
    echo "Verifying container user..."
    CONTAINER_USER=$(docker compose exec -T moltbot-gateway whoami 2>/dev/null || echo "unknown")
    if [ "$CONTAINER_USER" = "node" ]; then
        check_pass "Container is running as non-root user: $CONTAINER_USER"
    elif [ "$CONTAINER_USER" = "root" ]; then
        check_fail "Container is running as root (security risk)"
    else
        check_warn "Cannot determine container user"
    fi
    
    echo "Checking Docker socket access..."
    if docker compose exec -T moltbot-gateway test -e /var/run/docker.sock 2>/dev/null; then
        check_fail "Docker socket is accessible inside container"
    else
        check_pass "Docker socket is not accessible inside container"
    fi
    
    echo "Checking listening ports..."
    if command -v netstat &> /dev/null; then
        if netstat -an 2>/dev/null | grep LISTEN | grep -E '18789|18790' | grep -q "127.0.0.1"; then
            check_pass "Ports are listening on localhost only"
        elif netstat -an 2>/dev/null | grep LISTEN | grep -E '18789|18790' | grep -q "0.0.0.0"; then
            check_fail "Ports are listening on all interfaces (0.0.0.0)"
        else
            check_warn "Cannot determine port binding (ports may not be open)"
        fi
    elif command -v ss &> /dev/null; then
        if ss -ln 2>/dev/null | grep LISTEN | grep -E '18789|18790' | grep -q "127.0.0.1"; then
            check_pass "Ports are listening on localhost only"
        elif ss -ln 2>/dev/null | grep LISTEN | grep -E '18789|18790' | grep -q "0.0.0.0"; then
            check_fail "Ports are listening on all interfaces (0.0.0.0)"
        else
            check_warn "Cannot determine port binding (ports may not be open)"
        fi
    else
        check_warn "Cannot check port bindings (netstat/ss not available)"
    fi
else
    check_warn "Moltbot gateway is not running (skipping runtime checks)"
fi

# Section 5: Secret Detection
section "Secret Detection"

echo "Checking for secrets in git history..."
if [ -d ".git" ]; then
    if command -v git &> /dev/null; then
        # Check for common secret patterns in tracked files
        if git ls-files | xargs grep -l "sk-[A-Za-z0-9]" 2>/dev/null | grep -v ".secrets.baseline" | grep -qv "test"; then
            check_warn "Possible secrets found in tracked files (run detect-secrets scan)"
        else
            check_pass "No obvious secrets found in tracked files"
        fi
    fi
fi

echo "Checking .gitignore for secret patterns..."
if [ -f ".gitignore" ]; then
    if grep -q "\.env" .gitignore && grep -q "credentials" .gitignore; then
        check_pass ".gitignore includes common secret patterns"
    else
        check_warn ".gitignore may not cover all secret files"
    fi
fi

# Summary
section "Audit Summary"
echo ""
echo -e "${GREEN}Passed:  ${CHECKS_PASSED}${NC}"
echo -e "${YELLOW}Warnings: ${CHECKS_WARNED}${NC}"
echo -e "${RED}Failed:  ${CHECKS_FAILED}${NC}"
echo ""

if [ $CHECKS_FAILED -eq 0 ]; then
    if [ $CHECKS_WARNED -eq 0 ]; then
        echo -e "${GREEN}✓ All checks passed! Your security posture is excellent.${NC}"
        exit 0
    else
        echo -e "${YELLOW}⚠ All critical checks passed, but there are warnings to review.${NC}"
        exit 0
    fi
else
    echo -e "${RED}✗ Security audit failed. Please address the issues above.${NC}"
    exit 1
fi
