# Security Configuration Guide for Moltbot

This guide documents the security configuration requirements for running Moltbot with hardened settings.

## Gateway Configuration

### Gateway Authentication

The gateway should use token-based authentication to prevent unauthorized access, even from localhost.

#### Token Authentication Setup

Run the token rotation script to set up or update the gateway token:

```bash
bash scripts/rotate-gateway-token.sh
```

This will:
1. Generate a cryptographically secure random token (32 bytes, 64 hex characters)
2. Update or create `~/.moltbot/moltbot.json` with the token
3. Create a backup of the existing config
4. Set secure file permissions (600)

#### Using the Token

After generating a token, you'll need to provide it when accessing the gateway:

**Web UI:**
```
http://localhost:18789/?token=YOUR_TOKEN_HERE
```

**CLI:**
```bash
export CLAWDBOT_GATEWAY_TOKEN=YOUR_TOKEN_HERE
moltbot channels status
```

**Docker Compose:**
```yaml
environment:
  CLAWDBOT_GATEWAY_TOKEN: YOUR_TOKEN_HERE
```

#### Token Rotation

Rotate the token regularly (e.g., every 90 days) or immediately if:
- The token may have been exposed
- A team member leaves
- After a security incident
- When changing deployment environments

Simply run the rotation script again:
```bash
bash scripts/rotate-gateway-token.sh
```

### Loopback Bind Mode

The gateway should be configured to bind to loopback (`127.0.0.1`) only. This is configured in two places for defense in depth:

1. **Docker Compose** (already configured in `docker-compose.override.yml`)
2. **Runtime Configuration** (needs to be set by operator)

### Runtime Configuration File

Location: `~/.moltbot/moltbot.json` (or `~/.clawdbot/openclaw.json` for legacy installs)

Required configuration:

```json
{
  "gateway": {
    "bind": "loopback",
    "port": 18789
  }
}
```

This ensures that even if the Docker container is started without the override file, the gateway will still bind to loopback only.

## Configuration Options

### Gateway Bind Modes

- `loopback` - Bind to 127.0.0.1 only (recommended, most secure)
- `lan` - Bind to all local interfaces (not recommended)
- Specific IP address - Bind to a specific interface

**Recommendation**: Always use `loopback` unless you have a specific need and understand the security implications.

### Port Configuration

Default ports:
- Gateway: `18789`
- Bridge: `18790`

Both ports should be bound to `127.0.0.1` to prevent network exposure.

## Initial Setup

When first installing Moltbot, the configuration file may not exist. Create it with:

```bash
mkdir -p ~/.moltbot
cat > ~/.moltbot/moltbot.json << 'EOF'
{
  "gateway": {
    "bind": "loopback",
    "port": 18789
  }
}
EOF

# Set secure permissions
chmod 600 ~/.moltbot/moltbot.json
```

## Verification

After configuration, verify with the audit scripts:

```bash
bash scripts/quick-audit.sh
bash scripts/security-audit.sh
```

Both should show:
- ✓ Loopback bind mode is configured
- ✓ Ports are bound to localhost

## Remote Access

If you need to access the gateway remotely, use a secure tunnel such as:

### SSH Tunnel
```bash
ssh -L 18789:localhost:18789 user@gateway-host
```

### Tailscale
Configure Tailscale on both the gateway host and client machines, then access via Tailscale IP.

**Never** bind the gateway to `0.0.0.0` or a public interface without additional authentication and encryption.

## See Also

- `v2_implementationplan` - Full implementation plan
- `v2_changereport` - Security hardening changes
- `scripts/quick-audit.sh` - Fast security checks
- `scripts/security-audit.sh` - Comprehensive security audit
