#!/usr/bin/env bash
# Quick Security Audit for Moltbot
# Performs fast checks for common security issues

set -euo pipefail

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

CHECKS_PASSED=0
CHECKS_FAILED=0

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
}

echo "=== Moltbot Quick Security Audit ==="
echo ""

# Check 1: Verify Docker socket is not mounted
echo "Checking Docker socket exposure..."
if grep -r "/var/run/docker.sock" docker-compose*.yml 2>/dev/null | grep -v "^#"; then
    check_fail "Docker socket is mounted (security risk)"
else
    check_pass "No Docker socket mount found in compose files"
fi

# Check 2: Verify ports are bound to localhost
echo "Checking port bindings..."
if [ -f "docker-compose.override.yml" ]; then
    if grep -q "127.0.0.1:" docker-compose.override.yml 2>/dev/null; then
        check_pass "Ports are bound to localhost in override file"
    else
        check_warn "docker-compose.override.yml exists but may not restrict ports to localhost"
    fi
else
    check_warn "docker-compose.override.yml not found (create it to enforce localhost binding)"
fi

# Check 3: Verify non-root user in Dockerfile
echo "Checking Dockerfile user configuration..."
if grep -q "^USER node" Dockerfile 2>/dev/null; then
    check_pass "Dockerfile uses non-root user"
else
    check_fail "Dockerfile does not specify non-root user"
fi

# Check 4: Check for credentials directory permissions
echo "Checking credentials directory permissions..."
CRED_DIR="${HOME}/.moltbot/credentials"
if [ -d "$CRED_DIR" ]; then
    PERMS=$(stat -c %a "$CRED_DIR" 2>/dev/null || stat -f %A "$CRED_DIR" 2>/dev/null || echo "unknown")
    if [ "$PERMS" = "700" ]; then
        check_pass "Credentials directory has correct permissions (700)"
    else
        check_fail "Credentials directory has permissions $PERMS (should be 700)"
    fi
else
    check_warn "Credentials directory does not exist yet"
fi

# Check 5: Check for config file permissions
echo "Checking config file permissions..."
CONFIG_FILE="${HOME}/.moltbot/moltbot.json"
if [ -f "$CONFIG_FILE" ]; then
    PERMS=$(stat -c %a "$CONFIG_FILE" 2>/dev/null || stat -f %A "$CONFIG_FILE" 2>/dev/null || echo "unknown")
    if [ "$PERMS" = "600" ]; then
        check_pass "Config file has correct permissions (600)"
    else
        check_fail "Config file has permissions $PERMS (should be 600)"
    fi
else
    check_warn "Config file does not exist yet"
fi

# Check 6: Verify loopback bind mode in docker-compose
echo "Checking bind mode configuration..."
if grep -r "loopback" docker-compose*.yml 2>/dev/null | grep -v "^#"; then
    check_pass "Loopback bind mode is configured in compose files"
else
    check_warn "Bind mode may not be set to loopback (check docker-compose files)"
fi

# Summary
echo ""
echo "=== Audit Summary ==="
echo -e "Passed: ${GREEN}${CHECKS_PASSED}${NC}"
echo -e "Failed: ${RED}${CHECKS_FAILED}${NC}"

if [ $CHECKS_FAILED -eq 0 ]; then
    echo -e "${GREEN}All checks passed!${NC}"
    exit 0
else
    echo -e "${RED}Some checks failed. Review the issues above.${NC}"
    exit 1
fi
