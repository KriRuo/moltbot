# Security Quick Reference for Developers

This guide provides quick answers to common security questions for Moltbot contributors.

## 🚨 TL;DR - Most Important Rules

1. **Never commit secrets** - Use environment variables or `~/.moltbot/secrets.env`
2. **Validate all user input** - Especially before exec, eval, or file operations
3. **Use parameterized queries** - Never concatenate SQL strings
4. **Keep Node.js updated** - Require Node.js 22.12.0+ (has CVE patches)
5. **Run security checks** - Use pre-commit hooks and audit scripts

## 🔐 Quick Security Checks

### Before Committing
```bash
# Run pre-commit hooks
prek install  # One-time setup
git commit    # Hooks run automatically

# Or manually run checks
bash scripts/quick-audit.sh
```

### Common Pitfalls to Avoid

❌ **DON'T:**
```typescript
// DON'T: Hardcoded secrets
const API_KEY = "sk-ant-1234567890";

// DON'T: String concatenation in SQL
db.query(`SELECT * FROM users WHERE id = '${userId}'`);

// DON'T: Unsafe eval without validation
eval(userInput);

// DON'T: Path concatenation with user input
fs.readFile(`./files/${req.params.filename}`);
```

✅ **DO:**
```typescript
// DO: Environment variables for secrets
const API_KEY = process.env.ANTHROPIC_API_KEY;

// DO: Parameterized queries
db.query(`SELECT * FROM users WHERE id = ?`, [userId]);

// DO: Validate input before eval
validateOrThrow(functionBody);
const result = eval(functionBody);

// DO: Validate and sanitize file paths
const safePath = path.join(ALLOWED_DIR, path.basename(filename));
```

## 🛡️ Security Patterns to Use

### 1. Secrets Management

**Load from environment or config:**
```typescript
import { env } from "./config/env.js";

const token = env.CLAWDBOT_GATEWAY_TOKEN ?? config.gateway?.auth?.token;
if (!token) {
  throw new Error("Gateway token not configured");
}
```

**Store with secure permissions:**
```typescript
fs.writeFileSync(secretPath, content, { mode: 0o600 });
fs.chmodSync(secretPath, 0o600);  // Enforce even if umask is loose
```

### 2. Input Validation

**Browser evaluation (Playwright):**
```typescript
import { validateOrThrow } from "./browser/browser-eval-validator.js";

// Validates for dangerous patterns (fetch, localStorage, eval, etc.)
validateOrThrow(functionBody);
await page.evaluate(functionBody);
```

**Command execution:**
```typescript
// Use allowlist-based approval system
const approval = await getExecApproval(command, agent);
if (!approval.allowed) {
  throw new Error("Command not allowed");
}
```

**File paths:**
```typescript
import path from "node:path";

// Prevent path traversal
const safePath = path.resolve(baseDir, path.normalize(userInput));
if (!safePath.startsWith(baseDir)) {
  throw new Error("Path traversal detected");
}
```

### 3. Authentication

**Always use timing-safe comparison:**
```typescript
import { timingSafeEqual } from "node:crypto";

function safeEqual(a: string, b: string): boolean {
  if (a.length !== b.length) return false;
  return timingSafeEqual(Buffer.from(a), Buffer.from(b));
}
```

### 4. SQL Queries

**Use parameterized queries:**
```typescript
// ✅ Safe
const result = db.prepare("SELECT * FROM users WHERE id = ?").get(userId);

// ✅ Safe with multiple parameters
db.prepare("INSERT INTO logs (user, action) VALUES (?, ?)").run(user, action);
```

### 5. Network Security

**Bind to localhost by default:**
```typescript
const host = config.gateway?.bind === "lan" ? "0.0.0.0" : "127.0.0.1";
server.listen(port, host);
```

**Validate URLs before fetch:**
```typescript
function isSafeUrl(url: string): boolean {
  try {
    const parsed = new URL(url);
    // Block localhost/internal IPs
    if (["localhost", "127.0.0.1", "::1"].includes(parsed.hostname)) {
      return false;
    }
    // Only allow http/https
    return ["http:", "https:"].includes(parsed.protocol);
  } catch {
    return false;
  }
}
```

## 🧪 Testing Security Features

### Write Security Tests

```typescript
import { describe, expect, it } from "vitest";

describe("input validation", () => {
  it("blocks dangerous patterns", () => {
    expect(() => validateInput("'; DROP TABLE users--")).toThrow();
  });

  it("allows safe input", () => {
    expect(() => validateInput("hello world")).not.toThrow();
  });
});
```

### Test Authentication

```typescript
it("rejects invalid tokens", async () => {
  const result = await authenticateRequest({ token: "invalid" });
  expect(result.ok).toBe(false);
});

it("uses timing-safe comparison", async () => {
  // Measure timing to ensure constant-time
  const validToken = "a".repeat(32);
  const invalidToken = "b".repeat(32);
  
  const start1 = Date.now();
  await authenticateRequest({ token: validToken });
  const time1 = Date.now() - start1;
  
  const start2 = Date.now();
  await authenticateRequest({ token: invalidToken });
  const time2 = Date.now() - start2;
  
  // Times should be similar (within 10ms)
  expect(Math.abs(time1 - time2)).toBeLessThan(10);
});
```

## 🔍 Security Review Checklist

When adding new features, check:

- [ ] **Secrets:** No hardcoded API keys, passwords, or tokens
- [ ] **Input Validation:** All user input is validated/sanitized
- [ ] **SQL:** Using parameterized queries (no string concatenation)
- [ ] **File Operations:** No path traversal vulnerabilities
- [ ] **Network:** Localhost-only binding by default
- [ ] **Authentication:** Using timing-safe comparison for tokens
- [ ] **Authorization:** Checking permissions before sensitive operations
- [ ] **Logging:** Sensitive data is redacted in logs
- [ ] **Dependencies:** No known vulnerable dependencies added
- [ ] **Tests:** Security features have test coverage

## 📚 Where to Find Security Info

### Documentation
- **This File:** Quick reference for developers
- **SECURITY.md:** Security policy and reporting
- **SECURITY-AUDIT-REPORT.md:** Full security audit (25k+ words)
- **SECURITY-REVIEW-SUMMARY.md:** Executive summary of audit
- **SECURITY-IMPLEMENTATION.md:** Hardening implementation guide

### Code Examples
- **Auth:** `src/gateway/auth.ts` - Timing-safe token comparison
- **Validation:** `src/browser/browser-eval-validator.ts` - Input validation
- **Secrets:** `src/infra/exec-approvals.ts` - Secure file permissions
- **SQL:** `src/memory/manager.ts` - Parameterized queries

### Tools & Scripts
- **`scripts/quick-audit.sh`** - Fast security checks (6 tests, ~5 seconds)
- **`scripts/security-audit.sh`** - Comprehensive audit (20+ checks)
- **`scripts/secure-permissions.sh`** - Enforce 600/700 permissions
- **`scripts/rotate-gateway-token.sh`** - Generate secure tokens

## 🆘 Common Security Questions

### Q: How do I store API keys securely?

**A:** Use environment variables or `~/.moltbot/secrets.env`:

```bash
# ~/.moltbot/secrets.env (chmod 600)
export ANTHROPIC_API_KEY="sk-ant-..."
export OPENAI_API_KEY="sk-..."
```

In code:
```typescript
const apiKey = process.env.ANTHROPIC_API_KEY;
if (!apiKey) throw new Error("API key not configured");
```

### Q: Is it safe to use eval()?

**A:** Only with validation. Use the browser-eval-validator:

```typescript
import { validateOrThrow } from "./browser/browser-eval-validator.js";

// This will throw if dangerous patterns detected
validateOrThrow(functionBody);
const result = eval(functionBody);
```

For trusted contexts only, set:
```bash
export CLAWDBOT_ALLOW_DANGEROUS_BROWSER_EVAL=1
```

### Q: How do I prevent SQL injection?

**A:** Always use parameterized queries:

```typescript
// ✅ Safe
db.prepare("SELECT * FROM users WHERE id = ?").get(userId);

// ❌ Unsafe
db.query(`SELECT * FROM users WHERE id = '${userId}'`);
```

### Q: What permissions should files have?

**A:** 
- **Secrets:** 600 (owner read/write only)
- **Config:** 600 (owner read/write only)
- **Credentials directory:** 700 (owner access only)
- **Regular files:** 644 (owner write, everyone read)

Enforce with:
```bash
bash scripts/secure-permissions.sh
```

### Q: How do I validate file paths?

**A:** Use path.resolve and check prefix:

```typescript
import path from "node:path";

const baseDir = "/safe/directory";
const safePath = path.resolve(baseDir, path.normalize(userInput));

if (!safePath.startsWith(baseDir)) {
  throw new Error("Path traversal attempt detected");
}
```

### Q: Should I bind to 0.0.0.0 or 127.0.0.1?

**A:** Default to 127.0.0.1 (localhost only):

```typescript
const host = config.bind === "lan" ? "0.0.0.0" : "127.0.0.1";
```

Only use 0.0.0.0 when:
- User explicitly configures it
- Behind a reverse proxy with authentication
- With strong authentication (token + Tailscale)

### Q: How often should tokens be rotated?

**A:** 
- **Gateway tokens:** Quarterly (90 days)
- **API keys:** Quarterly or on compromise
- **Passwords:** Annually or on compromise

Use the rotation script:
```bash
bash scripts/rotate-gateway-token.sh
```

### Q: What Node.js version should I use?

**A:** Node.js 22.12.0 or later (includes security patches):

```bash
node --version  # Should be v22.12.0+
```

Critical CVEs fixed:
- CVE-2025-59466: async_hooks DoS
- CVE-2026-21636: Permission model bypass

## 🔧 Security Tools Commands

### Quick Security Audit (5 seconds)
```bash
bash scripts/quick-audit.sh
# Checks: Docker socket, port bindings, non-root user, permissions, loopback mode
```

### Comprehensive Audit (30 seconds)
```bash
bash scripts/security-audit.sh
# 20+ checks including: network config, secrets, Docker security, file permissions
```

### Enforce File Permissions
```bash
bash scripts/secure-permissions.sh
# Sets: ~/.moltbot/moltbot.json (600), ~/.moltbot/credentials (700)
```

### Generate Secure Token
```bash
bash scripts/rotate-gateway-token.sh
# Generates: 32-byte cryptographically secure token
```

### Detect Secrets Scan
```bash
detect-secrets scan --baseline .secrets.baseline
# Scans for: API keys, passwords, tokens, private keys
```

### Run Security Tests
```bash
npm test src/browser/browser-eval-validator.test.ts
# Tests: Input validation, dangerous pattern detection
```

## 🎯 Quick Wins for Better Security

1. **Enable pre-commit hooks** (one-time):
   ```bash
   prek install
   ```

2. **Run quick audit** (before each release):
   ```bash
   bash scripts/quick-audit.sh
   ```

3. **Enforce permissions** (weekly):
   ```bash
   bash scripts/secure-permissions.sh
   ```

4. **Check secrets** (before commits):
   ```bash
   detect-secrets scan
   ```

5. **Update dependencies** (monthly):
   ```bash
   npm audit
   npm update
   ```

## 📞 Need Help?

- **Security Issues:** Email steipete@gmail.com (private reporting)
- **Questions:** Check `SECURITY-AUDIT-REPORT.md` for detailed explanations
- **Implementation:** See `SECURITY-IMPLEMENTATION.md` for step-by-step guides

---

**Quick Reference Version:** 1.0  
**Last Updated:** February 7, 2026  
**Full Documentation:** See `SECURITY-AUDIT-REPORT.md`
