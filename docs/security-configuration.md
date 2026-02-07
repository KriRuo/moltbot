# Security Configuration Guide for Moltbot

This guide documents the security configuration requirements for running Moltbot with hardened settings.

## Gateway Configuration

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
