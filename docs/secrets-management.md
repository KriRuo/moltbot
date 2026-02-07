# Secrets Management Guide

## Overview

This guide documents best practices for managing secrets (API keys, tokens, credentials) in Moltbot deployments.

## Principles

1. **Never commit secrets to git** - Use `.gitignore` to exclude secret files
2. **Separate secrets from code** - Store secrets separately from configuration
3. **Use environment variables** - Pass secrets at runtime, not in files
4. **Encrypt at rest** - Use encrypted filesystems or secret managers
5. **Rotate regularly** - Change secrets periodically and after incidents
6. **Audit access** - Know who has access to which secrets
7. **Redact from logs** - Ensure secrets don't appear in log files

## Secret Storage Locations

### DO NOT Store Secrets Here ❌

- Git repositories (`.git` history)
- Docker images
- Unencrypted cloud storage
- Shared directories with broad access
- Log files
- Error messages
- Environment variables visible to all processes

### Safe Storage Options ✅

1. **Local encrypted file** (for development/testing)
   - `~/.moltbot/secrets.env` with 600 permissions
   - Full disk encryption enabled
   - Regular backups (encrypted)

2. **System secret managers** (recommended for production)
   - **Linux**: `systemd` credentials, `gnome-keyring`, `pass`
   - **macOS**: Keychain
   - **Cloud**: AWS Secrets Manager, Azure Key Vault, Google Secret Manager

3. **Environment variables from secure source**
   - Loaded at startup only
   - Not persisted to disk
   - Unset after passing to application

## Setup Guide

### Step 1: Create Secrets File

Create `~/.moltbot/secrets.env`:

```bash
# Create the file
touch ~/.moltbot/secrets.env

# Set restrictive permissions immediately
chmod 600 ~/.moltbot/secrets.env

# Edit with your secrets
nano ~/.moltbot/secrets.env
```

### Step 2: Add Secrets

Add the following to `~/.moltbot/secrets.env`:

```bash
# Gateway Authentication (required)
# Generate with: bash scripts/rotate-gateway-token.sh
export CLAWDBOT_GATEWAY_TOKEN="your_gateway_token_here"

# AI Provider API Keys (at least one required)
export ANTHROPIC_API_KEY="sk-ant-..."
export OPENAI_API_KEY="sk-..."
export GOOGLE_API_KEY="..."

# Channel Credentials (as needed)
export TELEGRAM_BOT_TOKEN="..."
export DISCORD_BOT_TOKEN="..."
export SLACK_BOT_TOKEN="..."

# Optional: Claude web access
export CLAUDE_WEB_SESSION_KEY="..."
export CLAUDE_WEB_COOKIE="..."
```

### Step 3: Secure the File

```bash
# Verify permissions
ls -la ~/.moltbot/secrets.env
# Should show: -rw------- (600)

# If not, fix it:
chmod 600 ~/.moltbot/secrets.env

# Verify ownership
# Should be owned by your user, not root
stat -c "%U" ~/.moltbot/secrets.env
```

### Step 4: Use the Secure Startup Script

```bash
# Start Moltbot with secrets loaded securely
bash scripts/start-moltbot.sh
```

The script will:
1. Load secrets from `~/.moltbot/secrets.env`
2. Verify required secrets are present
3. Set secure filesystem permissions
4. Start Moltbot with secrets
5. Unset secrets from the shell environment

## Secrets by Category

### Gateway Secrets

**Token** (`CLAWDBOT_GATEWAY_TOKEN`):
- Used for: Gateway authentication
- Generate: `bash scripts/rotate-gateway-token.sh`
- Rotate: Every 90 days or after exposure
- Length: 64 hex characters (32 bytes)

### AI Provider Secrets

**Anthropic** (`ANTHROPIC_API_KEY`):
- Format: `sk-ant-api03-...`
- Get from: https://console.anthropic.com/
- Models: Claude 3.5 Sonnet, Claude 3 Opus, etc.

**OpenAI** (`OPENAI_API_KEY`):
- Format: `sk-...`
- Get from: https://platform.openai.com/api-keys
- Models: GPT-4, GPT-3.5, etc.

**Google** (`GOOGLE_API_KEY`):
- Get from: https://makersuite.google.com/app/apikey
- Models: Gemini Pro, etc.

### Messaging Platform Secrets

**Telegram** (`TELEGRAM_BOT_TOKEN`):
- Get from: @BotFather on Telegram
- Format: `1234567890:ABCdefGHIjklMNOpqrsTUVwxyz`

**Discord** (`DISCORD_BOT_TOKEN`):
- Get from: https://discord.com/developers/applications
- Store token only, not the full `DISCORD_BOT_TOKEN=` prefix

**Slack** (`SLACK_BOT_TOKEN`):
- Get from: https://api.slack.com/apps
- Format: `xoxb-...`

## Log Redaction

### Configuration

Add to `~/.moltbot/moltbot.json`:

```json
{
  "logging": {
    "redactSensitive": "tools"
  }
}
```

Options:
- `"none"` - No redaction (not recommended)
- `"tools"` - Redact tool inputs/outputs containing secrets
- `"all"` - Aggressive redaction (may impact debugging)

### What Gets Redacted

When `redactSensitive` is enabled:
- API keys matching patterns (sk-, xoxb-, etc.)
- Bearer tokens
- Authorization headers
- Tool inputs containing credentials
- Error messages with secrets

### Verification

Check logs for secrets:

```bash
# Docker
docker compose logs | grep -E "sk-|Bearer |xoxb-" || echo "No secrets found (good)"

# Local
cat /tmp/moltbot-gateway.log | grep -E "sk-|Bearer |xoxb-" || echo "No secrets found (good)"
```

## Secret Rotation

### When to Rotate

**Immediately rotate if:**
- Secret may have been exposed (logs, commits, etc.)
- Team member with access leaves
- Security incident or breach
- Suspicious activity detected

**Regularly rotate:**
- Gateway token: Every 90 days
- AI provider keys: Every 180 days (or per provider policy)
- Channel tokens: Every 180 days

### How to Rotate

1. **Generate new secret:**
   ```bash
   # Gateway token
   bash scripts/rotate-gateway-token.sh
   
   # AI provider keys
   # Use provider's console to create new key
   ```

2. **Update secrets file:**
   ```bash
   nano ~/.moltbot/secrets.env
   # Replace old secret with new one
   ```

3. **Restart Moltbot:**
   ```bash
   docker compose restart
   # or
   moltbot gateway restart
   ```

4. **Verify new secret works:**
   ```bash
   bash scripts/quick-audit.sh
   moltbot channels status
   ```

5. **Revoke old secret:**
   - Use provider's console to delete/revoke old key

## .gitignore Configuration

Ensure your `.gitignore` includes:

```gitignore
# Secrets
.env
.env.local
.env.*.local
*.env
secrets.env
credentials/
*.key
*.pem

# Config with secrets
**/openclaw.json
**/clawdbot.json
**/moltbot.json
**/.clawdbot/
**/.moltbot/

# Backups that might contain secrets
*.backup
*.bak
```

Already included in the repository's `.gitignore`:
```gitignore
.env
.env.*
!.env.example
```

## Audit & Verification

### Check for Secrets in Git

```bash
# Scan for secrets in git history
bash scripts/security-audit.sh

# Or use detect-secrets
detect-secrets scan
```

### Check File Permissions

```bash
# Run security audit
bash scripts/security-audit.sh

# Or check manually
ls -la ~/.moltbot/secrets.env
stat -c "%a" ~/.moltbot/secrets.env  # Should be 600
```

### Check for Secrets in Logs

```bash
# Check Docker logs
docker compose logs 2>&1 | grep -E "sk-|Bearer |xoxb-"

# Check local logs
cat /tmp/moltbot-gateway.log | grep -E "sk-|Bearer |xoxb-"
```

Expected: No matches (secrets should be redacted)

## Incident Response

### If a Secret is Exposed

1. **Immediately revoke the secret** at the provider
2. **Generate a new secret** using provider's console
3. **Update your `secrets.env`** file
4. **Restart Moltbot** with new secret
5. **Check logs** for unauthorized usage
6. **Rotate related secrets** as a precaution
7. **Review git history** if committed
8. **Document the incident** for future reference

### If Secrets in Git History

If secrets were committed to git:

```bash
# Option 1: Use BFG Repo-Cleaner (recommended)
bfg --replace-text secrets.txt repo.git

# Option 2: Use git filter-branch (complex)
git filter-branch --force --index-filter \
  'git rm --cached --ignore-unmatch secrets.env' \
  --prune-empty --tag-name-filter cat -- --all

# Force push (WARNING: destructive)
git push origin --force --all
```

**Important:** Even after removing from git, assume the secrets are compromised and rotate them.

## Best Practices Summary

✅ **DO:**
- Use `scripts/start-moltbot.sh` for secure startup
- Store secrets in `~/.moltbot/secrets.env` with 600 permissions
- Enable log redaction (`logging.redactSensitive: "tools"`)
- Rotate secrets regularly
- Use full disk encryption
- Review security audit output
- Use system secret managers in production

❌ **DON'T:**
- Commit secrets to git
- Store secrets in Docker images
- Share secrets via unsecured channels
- Use overly permissive file permissions
- Disable log redaction
- Reuse secrets across environments
- Store secrets in cloud sync folders

## See Also

- `scripts/start-moltbot.sh` - Secure startup wrapper
- `scripts/rotate-gateway-token.sh` - Token rotation
- `scripts/security-audit.sh` - Security verification
- `docs/security-configuration.md` - Security settings
- `.gitignore` - Excluded patterns
