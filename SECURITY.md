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
