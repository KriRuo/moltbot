#!/usr/bin/env bash
# Secure Permissions Script for Moltbot
# Enforces 700/600 permissions on sensitive configuration and credential files

set -euo pipefail

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

CHANGES_MADE=0
ERRORS=0

# Determine the Moltbot directory (support both moltbot and clawdbot names)
if [ -d "${HOME}/.moltbot" ]; then
    MOLTBOT_DIR="${HOME}/.moltbot"
elif [ -d "${HOME}/.clawdbot" ]; then
    MOLTBOT_DIR="${HOME}/.clawdbot"
else
    echo -e "${YELLOW}⚠${NC} Moltbot directory not found. Creating ${HOME}/.moltbot"
    mkdir -p "${HOME}/.moltbot"
    MOLTBOT_DIR="${HOME}/.moltbot"
fi

echo -e "${BLUE}╔════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║  Moltbot Secure Permissions Script        ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════╝${NC}"
echo ""
echo "Working directory: $MOLTBOT_DIR"
echo ""

secure_directory() {
    local dir="$1"
    local target_perms="700"
    
    if [ ! -d "$dir" ]; then
        return
    fi
    
    current_perms=$(stat -c %a "$dir" 2>/dev/null || stat -f %A "$dir" 2>/dev/null || echo "unknown")
    
    if [ "$current_perms" != "$target_perms" ]; then
        echo -e "${YELLOW}Fixing:${NC} $dir (${current_perms} → ${target_perms})"
        if chmod "$target_perms" "$dir" 2>/dev/null; then
            ((CHANGES_MADE++)) || true
        else
            echo -e "${RED}Error:${NC} Failed to chmod $dir"
            ((ERRORS++)) || true
        fi
    else
        echo -e "${GREEN}✓${NC} $dir ($current_perms)"
    fi
}

secure_file() {
    local file="$1"
    local target_perms="600"
    
    if [ ! -f "$file" ]; then
        return
    fi
    
    current_perms=$(stat -c %a "$file" 2>/dev/null || stat -f %A "$file" 2>/dev/null || echo "unknown")
    
    if [ "$current_perms" != "$target_perms" ]; then
        echo -e "${YELLOW}Fixing:${NC} $file (${current_perms} → ${target_perms})"
        if chmod "$target_perms" "$file" 2>/dev/null; then
            ((CHANGES_MADE++)) || true
        else
            echo -e "${RED}Error:${NC} Failed to chmod $file"
            ((ERRORS++)) || true
        fi
    else
        echo -e "${GREEN}✓${NC} $file ($current_perms)"
    fi
}

# Secure the main Moltbot directory
echo "Securing main directory..."
secure_directory "$MOLTBOT_DIR"
echo ""

# Secure credentials directory
echo "Securing credentials directory..."
CRED_DIR="${MOLTBOT_DIR}/credentials"
if [ -d "$CRED_DIR" ]; then
    secure_directory "$CRED_DIR"
    
    # Secure all files in credentials directory
    find "$CRED_DIR" -type f 2>/dev/null | while IFS= read -r file; do
        secure_file "$file"
    done
else
    echo -e "${YELLOW}⚠${NC} Credentials directory does not exist yet: $CRED_DIR"
    echo "   (This is normal if Moltbot hasn't been configured yet)"
fi
echo ""

# Secure main config file
echo "Securing main config file..."
for config_name in "moltbot.json" "openclaw.json" "clawdbot.json"; do
    config_file="${MOLTBOT_DIR}/${config_name}"
    if [ -f "$config_file" ]; then
        secure_file "$config_file"
    fi
done
echo ""

# Secure agent auth profiles
echo "Securing agent auth profiles..."
if find "$MOLTBOT_DIR" -name "auth-profiles.json" 2>/dev/null | grep -q .; then
    find "$MOLTBOT_DIR" -name "auth-profiles.json" 2>/dev/null | while IFS= read -r profile; do
        if [ -n "$profile" ]; then
            secure_file "$profile"
        fi
    done
else
    echo -e "${YELLOW}⚠${NC} No auth profiles found yet"
    echo "   (This is normal if agents haven't been configured yet)"
fi
echo ""

# Secure sessions directory if it contains sensitive data
echo "Securing sessions directory..."
SESSIONS_DIR="${MOLTBOT_DIR}/sessions"
if [ -d "$SESSIONS_DIR" ]; then
    secure_directory "$SESSIONS_DIR"
    
    # Secure WhatsApp auth files specifically
    if [ -d "${SESSIONS_DIR}/whatsapp" ]; then
        secure_directory "${SESSIONS_DIR}/whatsapp"
        find "${SESSIONS_DIR}/whatsapp" -type f -name "*.json" 2>/dev/null | while IFS= read -r file; do
            if [ -n "$file" ]; then
                secure_file "$file"
            fi
        done
    fi
else
    echo -e "${YELLOW}⚠${NC} Sessions directory does not exist yet: $SESSIONS_DIR"
fi
echo ""

# Summary
echo -e "${BLUE}═══════════════════════════════════════════${NC}"
echo "Summary:"
echo -e "  Changes made: ${YELLOW}${CHANGES_MADE}${NC}"
echo -e "  Errors: ${RED}${ERRORS}${NC}"
echo ""

if [ $ERRORS -gt 0 ]; then
    echo -e "${RED}✗${NC} Completed with errors"
    exit 1
elif [ $CHANGES_MADE -gt 0 ]; then
    echo -e "${GREEN}✓${NC} Successfully secured $CHANGES_MADE items"
    exit 0
else
    echo -e "${GREEN}✓${NC} All permissions already secure"
    exit 0
fi
