# Security Policy

If you believe you've found a security issue in Moltbot, please report it privately.

## Reporting

- Email: `steipete@gmail.com`
- What to include: reproduction steps, impact assessment, and (if possible) a minimal PoC.

## Operational Guidance

For threat model + hardening guidance (including `moltbot security audit --deep` and `--fix`), see:

- `https://docs.molt.bot/gateway/security`

### Web Interface Safety

Moltbot's web interface is intended for local use only. Do **not** bind it to the public internet; it is not hardened for public exposure.

### Browser Automation Security

Moltbot's browser automation tools include input validation to prevent code injection in browser contexts. Functions executed in the browser are validated for dangerous patterns (network requests, storage access, credential theft, etc.) before execution.

**For trusted environments only:** You can bypass validation by setting `CLAWDBOT_ALLOW_DANGEROUS_BROWSER_EVAL=1`. This should **only** be used when:
- All browser evaluation input comes from trusted sources
- You understand the security implications
- You need to use patterns blocked by default validation

See `SECURITY-AUDIT-REPORT.md` for details on browser evaluation security.

## Runtime Requirements

### Node.js Version

Moltbot requires **Node.js 22.12.0 or later** (LTS). This version includes important security patches:

- CVE-2025-59466: async_hooks DoS vulnerability
- CVE-2026-21636: Permission model bypass vulnerability

Verify your Node.js version:

```bash
node --version  # Should be v22.12.0 or later
```

### Docker Security

When running Moltbot in Docker:

1. The official image runs as a non-root user (`node`) for reduced attack surface
2. Use `--read-only` flag when possible for additional filesystem protection
3. Limit container capabilities with `--cap-drop=ALL`

Example secure Docker run:

```bash
docker run --read-only --cap-drop=ALL \
  -v moltbot-data:/app/data \
  moltbot/moltbot:latest
```

## Security Scanning

This project uses `detect-secrets` for automated secret detection in CI/CD.
See `.detect-secrets.cfg` for configuration and `.secrets.baseline` for the baseline.

Run locally:

```bash
pip install detect-secrets==1.5.0
detect-secrets scan --baseline .secrets.baseline
```

## Runtime Data Security

### Data Storage & Privacy

Moltbot stores data locally on your device. Understanding what data is stored and how to manage it is critical for security and privacy compliance.

#### What Data Is Stored

1. **Session Transcripts** (`~/.clawdbot/sessions/`)
   - Full conversation history with users
   - User identifiers (phone numbers, usernames)
   - Timestamps and message metadata
   - **Retention:** Indefinite (no automatic cleanup)
   - **Encryption:** None (plaintext JSON files)

2. **Memory Database** (`~/.clawdbot/memory/`)
   - SQLite database with document chunks
   - Vector embeddings for semantic search
   - May contain session transcript excerpts
   - **Retention:** Indefinite (until manually reset)
   - **Encryption:** None (standard SQLite)

3. **Configuration & Credentials** (`~/.clawdbot/config/`)
   - Gateway authentication tokens
   - Channel API keys and tokens
   - User preferences and allowlists
   - **Retention:** Indefinite (until manually deleted)
   - **Encryption:** None (plaintext JSON5)

4. **Logs** (location varies by platform)
   - Application events and errors
   - User actions (with sensitive data redacted by default)
   - **Retention:** Platform-dependent (OS log rotation)
   - **Encryption:** None

#### Data Protection Recommendations

**For Personal Use:**
- Enable full-disk encryption (FileVault, LUKS, BitLocker)
- Use strong gateway passwords
- Regularly clean old session data
- Use local AI models to keep data on-device

**For Organizational Use:**
- Implement automated data retention policies
- Enable HTTPS for gateway with valid certificates
- Use Tailscale or VPN for remote access
- Conduct regular security audits
- See `GDPR_DATA_PRIVACY.md` for compliance guidance

#### Manual Data Cleanup

```bash
# Delete old sessions (older than 90 days)
find ~/.clawdbot/sessions/ -type f -name "*.json" -mtime +90 -delete

# Reset memory database for an agent
moltbot memory reset --agent <agentId>

# Complete data wipe (⚠️ IRREVERSIBLE)
rm -rf ~/.clawdbot/
```

#### Sensitive Data Redaction

Logging automatically redacts sensitive information by default:
- API keys and tokens (sk-\*, ghp_\*, xox\*, etc.)
- Passwords in environment variables
- Bearer tokens and auth headers
- PEM private keys

To verify redaction is enabled:
```bash
moltbot config get logging.redactSensitive
# Should return: "tools" (default) or "all"
```

To disable (not recommended):
```bash
moltbot config set logging.redactSensitive off
```

### GDPR & Privacy Compliance

For information about GDPR compliance, user rights, and data privacy practices, see:

- **GDPR_DATA_PRIVACY.md** - Comprehensive guide for GDPR compliance
- **User Rights:** Data access, deletion, portability, rectification
- **Data Retention:** Recommendations and manual cleanup procedures
- **Third-Party Processors:** AI provider data handling policies

**Key Considerations:**
- Moltbot is designed for self-hosted use (you are the data controller)
- No data is sent to Moltbot maintainers or external services (except configured AI providers)
- Organizations using Moltbot must implement their own GDPR compliance measures
- See GDPR_DATA_PRIVACY.md for organizational deployment guidance
