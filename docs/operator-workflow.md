# Moltbot Operator Workflow Guide

## Overview

This guide documents the complete workflow for operators to deploy, configure, and maintain a hardened Moltbot instance following the security implementation plan.

## Prerequisites

- WSL2 (Windows Subsystem for Linux 2) or native Linux/macOS
- Docker and Docker Compose installed
- Basic command-line familiarity
- Understanding of the security requirements

## Initial Setup

### Step 1: Clone the Repository

```bash
git clone https://github.com/KriRuo/moltbot.git
cd moltbot
```

### Step 2: Verify Security Controls

Run the audit scripts to verify the security posture:

```bash
# Quick audit (fast, essential checks)
bash scripts/quick-audit.sh

# Comprehensive audit (detailed analysis)
bash scripts/security-audit.sh
```

**Expected Result:** All critical checks should pass ✅

### Step 3: Set Up Secrets

Create the secrets file:

```bash
# Create secrets file
touch ~/.moltbot/secrets.env
chmod 600 ~/.moltbot/secrets.env

# Edit with your secrets
nano ~/.moltbot/secrets.env
```

Add the following to `~/.moltbot/secrets.env`:

```bash
# Gateway Authentication
export CLAWDBOT_GATEWAY_TOKEN=""  # Will be generated in next step

# AI Provider (at least one required)
export ANTHROPIC_API_KEY="sk-ant-..."
# or
export OPENAI_API_KEY="sk-..."
# or
export GOOGLE_API_KEY="..."

# Channel Credentials (as needed)
export TELEGRAM_BOT_TOKEN="..."
export DISCORD_BOT_TOKEN="..."
```

Save and close (Ctrl+X, Y, Enter).

### Step 4: Generate Gateway Token

```bash
bash scripts/rotate-gateway-token.sh
```

This will:
1. Generate a secure 32-byte random token
2. Update `~/.moltbot/moltbot.json` with token authentication
3. Display the token for you to copy

**Copy the token** and add it to `~/.moltbot/secrets.env`:

```bash
export CLAWDBOT_GATEWAY_TOKEN="<paste-token-here>"
```

### Step 5: Configure Runtime Settings

Edit `~/.moltbot/moltbot.json`:

```bash
nano ~/.moltbot/moltbot.json
```

Ensure it has at minimum:

```json
{
  "gateway": {
    "bind": "loopback",
    "port": 18789,
    "auth": {
      "mode": "token",
      "token": "<your-token-here>"
    }
  },
  "logging": {
    "redactSensitive": "tools"
  }
}
```

Save and close.

### Step 6: Secure Filesystem Permissions

```bash
bash scripts/secure-permissions.sh
```

This will:
- Set directories to 700 permissions
- Set config/credential files to 600 permissions
- Report what was changed

### Step 7: Configure WhatsApp (Optional)

If using WhatsApp, add safe defaults to `~/.moltbot/moltbot.json`:

```json
{
  "channels": {
    "whatsapp": {
      "enabled": true,
      "dmPolicy": "pairing",
      "groupPolicy": "mention-only",
      "dmAllowlist": [],
      "groupAllowlist": [],
      "requireMentionInGroups": true
    }
  }
}
```

See `docs/phase9-whatsapp-safe-defaults.md` for detailed configuration options.

## Starting Moltbot

### Using the Secure Startup Script (Recommended)

```bash
bash scripts/start-moltbot.sh
```

This script:
1. Loads secrets from `~/.moltbot/secrets.env`
2. Verifies required secrets are set
3. Runs `secure-permissions.sh` automatically
4. Starts Moltbot via Docker Compose or CLI
5. Unsets secrets from the shell

### Manual Start (Alternative)

If you need to start manually:

```bash
# Load secrets
set -a
source ~/.moltbot/secrets.env
set +a

# Secure permissions
bash scripts/secure-permissions.sh

# Start with Docker Compose
docker compose up -d

# Or start with CLI
moltbot gateway --bind loopback --port 18789
```

## Daily Operations

### Check Status

```bash
# Docker Compose
docker compose ps
docker compose logs -f moltbot-gateway

# CLI
moltbot channels status
moltbot gateway status
```

### Access Web UI

```bash
# Get your gateway token
cat ~/.moltbot/moltbot.json | grep token

# Access UI with token
# http://localhost:18789/?token=<your-token>
```

### Monitor Logs

```bash
# Docker
docker compose logs -f moltbot-gateway

# CLI
tail -f /tmp/moltbot-gateway.log

# Look for errors or suspicious activity
docker compose logs moltbot-gateway | grep -i error
```

### Check Security Posture

```bash
# Quick check (daily)
bash scripts/quick-audit.sh

# Comprehensive check (weekly)
bash scripts/security-audit.sh
```

## Maintenance Tasks

### Rotate Gateway Token (Every 90 Days)

```bash
# Generate new token
bash scripts/rotate-gateway-token.sh

# Update secrets file
nano ~/.moltbot/secrets.env
# Update CLAWDBOT_GATEWAY_TOKEN with new token

# Restart gateway
docker compose restart moltbot-gateway
```

### Update AI Provider Keys (Every 180 Days)

```bash
# Get new key from provider console
# (Anthropic, OpenAI, Google)

# Update secrets file
nano ~/.moltbot/secrets.env
# Update the relevant API key

# Restart gateway
docker compose restart moltbot-gateway

# Revoke old key at provider console
```

### Secure Permissions (Weekly)

```bash
# Run permission enforcement
bash scripts/secure-permissions.sh

# Should show: "All permissions already secure"
# If changes were made, investigate why
```

### Review Allowlists (Monthly)

```bash
# Check current allowlists
cat ~/.moltbot/moltbot.json | jq '.channels.whatsapp'

# Remove inactive users/groups
nano ~/.moltbot/moltbot.json
# Edit allowlists

# Restart to apply changes
docker compose restart moltbot-gateway
```

## Troubleshooting

### Gateway Won't Start

1. **Check secrets:**
   ```bash
   # Verify secrets file exists and has correct permissions
   ls -la ~/.moltbot/secrets.env
   # Should be: -rw------- (600)
   
   # Verify required secrets are set
   source ~/.moltbot/secrets.env
   echo $CLAWDBOT_GATEWAY_TOKEN
   echo $ANTHROPIC_API_KEY
   ```

2. **Check ports:**
   ```bash
   # Verify nothing else is using the ports
   netstat -an | grep -E '18789|18790'
   # or
   ss -ln | grep -E '18789|18790'
   ```

3. **Check logs:**
   ```bash
   docker compose logs moltbot-gateway
   ```

### Cannot Access Web UI

1. **Verify gateway is running:**
   ```bash
   docker compose ps
   # moltbot-gateway should be "Up"
   ```

2. **Check token:**
   ```bash
   cat ~/.moltbot/moltbot.json | grep token
   # Use this token in the URL:
   # http://localhost:18789/?token=<token>
   ```

3. **Verify localhost binding:**
   ```bash
   bash scripts/quick-audit.sh
   # Should show: "Ports are bound to localhost"
   ```

### Secrets in Logs

If secrets appear in logs:

1. **Enable log redaction:**
   ```json
   {
     "logging": {
       "redactSensitive": "tools"
     }
   }
   ```

2. **Clear existing logs:**
   ```bash
   docker compose logs --no-log-prefix moltbot-gateway > /dev/null
   # Or delete log files
   ```

3. **Rotate any exposed secrets immediately**

### Permission Errors

```bash
# Re-run permission enforcement
bash scripts/secure-permissions.sh

# If still failing, check ownership
ls -la ~/.moltbot
# Should be owned by your user, not root

# Fix ownership if needed
sudo chown -R $(whoami):$(whoami) ~/.moltbot
bash scripts/secure-permissions.sh
```

## Security Incident Response

### If a Secret is Exposed

1. **Immediately revoke the secret** at the provider
2. **Generate a new secret** using provider console
3. **Update `~/.moltbot/secrets.env`**
4. **Restart Moltbot**
5. **Check logs for unauthorized usage**
6. **Review access logs** at provider
7. **Document the incident**

### If Suspicious Activity Detected

1. **Stop the gateway immediately:**
   ```bash
   docker compose down
   ```

2. **Review logs for the suspicious activity:**
   ```bash
   docker compose logs moltbot-gateway > incident-logs.txt
   ```

3. **Check configuration:**
   ```bash
   bash scripts/security-audit.sh > audit-report.txt
   ```

4. **Rotate all secrets** (gateway token, API keys)

5. **Review and tighten allowlists** (WhatsApp, other channels)

6. **Restart with fresh logs:**
   ```bash
   docker compose up -d
   ```

7. **Monitor closely** for 24-48 hours

## Backup and Recovery

### What to Backup

**Critical (encrypted backups):**
- `~/.moltbot/secrets.env` (secrets)
- `~/.moltbot/moltbot.json` (config with token)
- `~/.moltbot/credentials/` (channel credentials)

**Important (can be regenerated):**
- `~/.moltbot/sessions/` (session data)
- Channel pairing data

**Not needed:**
- Logs
- Temporary files

### Backup Procedure

```bash
# Create encrypted backup
tar czf - ~/.moltbot | gpg -c > moltbot-backup-$(date +%Y%m%d).tar.gz.gpg

# Store securely (not in cloud sync!)
mv moltbot-backup-*.tar.gz.gpg ~/secure-backups/
```

### Recovery Procedure

```bash
# Extract encrypted backup
gpg -d moltbot-backup-YYYYMMDD.tar.gz.gpg | tar xz -C /

# Secure permissions
bash scripts/secure-permissions.sh

# Verify configuration
bash scripts/quick-audit.sh

# Start Moltbot
bash scripts/start-moltbot.sh
```

## Routine Checklist

### Daily
- [ ] Check gateway status (`docker compose ps`)
- [ ] Review logs for errors (`docker compose logs --tail 50`)
- [ ] Verify web UI is accessible

### Weekly
- [ ] Run quick audit (`bash scripts/quick-audit.sh`)
- [ ] Run permission enforcement (`bash scripts/secure-permissions.sh`)
- [ ] Review recent activity logs

### Monthly
- [ ] Run comprehensive audit (`bash scripts/security-audit.sh`)
- [ ] Review and prune allowlists
- [ ] Check for Moltbot updates
- [ ] Verify backup integrity

### Quarterly (Every 90 Days)
- [ ] Rotate gateway token (`bash scripts/rotate-gateway-token.sh`)
- [ ] Review all secrets and rotate as needed
- [ ] Update dependencies
- [ ] Review security documentation for updates

## Support Resources

- **Security Configuration:** `docs/security-configuration.md`
- **Secrets Management:** `docs/secrets-management.md`
- **WhatsApp Configuration:** `docs/phase9-whatsapp-safe-defaults.md`
- **Quick Audit:** `bash scripts/quick-audit.sh`
- **Comprehensive Audit:** `bash scripts/security-audit.sh`
- **Permission Enforcement:** `bash scripts/secure-permissions.sh`
- **Token Rotation:** `bash scripts/rotate-gateway-token.sh`
- **Secure Startup:** `bash scripts/start-moltbot.sh`

## Summary

This workflow ensures:
- ✅ Secure initial setup
- ✅ Proper secrets management
- ✅ Regular security audits
- ✅ Timely secret rotation
- ✅ Incident response capability
- ✅ Reliable backup and recovery

Follow this workflow to maintain a secure and reliable Moltbot deployment.
