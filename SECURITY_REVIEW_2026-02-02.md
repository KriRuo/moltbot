# Comprehensive Security Review - Moltbot Repository
**Date:** February 2, 2026  
**Reviewer:** Application Security Engineer  
**Repository:** KriRuo/moltbot  
**Commit:** Latest (as of 2026-02-02)

---

## Executive Summary

### Business Risk Summary

Moltbot is a WhatsApp gateway CLI and AI agent platform with multiple messaging channel integrations (WhatsApp, Telegram, Discord, Slack, Signal, iMessage, etc.) and extensive automation capabilities. The application handles sensitive user communications, credentials, and provides shell execution capabilities through various interfaces.

**Critical Finding:** The application contains **5 HIGH and CRITICAL severity vulnerabilities** that could allow unauthorized access to user sessions, arbitrary command execution, and SQL injection. The most severe issues include:
1. **Command injection via TUI local shell** allowing arbitrary code execution
2. **IDOR vulnerabilities** enabling unauthorized session access
3. **Missing rate limiting** on critical API endpoints
4. **SQL injection risks** in database schema operations
5. **GitHub Actions security** with over-scoped permissions and unpinned actions

The application demonstrates strong security practices in some areas (secrets management, authentication tokens, Dependabot configuration) but has critical gaps in input validation, authorization checks, and secure command execution.

### Top 5 Risks

1. **Command Injection in TUI Shell** - Arbitrary code execution via user input with `shell: true` (CRITICAL)
2. **Session IDOR Vulnerability** - Unauthorized access to arbitrary user sessions via sessionKey parameter (HIGH)
3. **SQL Injection in Schema Operations** - Direct string interpolation in table/column names (HIGH)
4. **Missing Rate Limiting** - No throttling on critical API endpoints enabling DoS attacks (MEDIUM-HIGH)
5. **GitHub Actions Security** - `pull_request_target` with write permissions and unpinned actions (MEDIUM-HIGH)

### Overall Risk Rating: **HIGH**

**Key Risk Drivers:**
- Multiple command injection vectors with minimal input validation
- Authorization bypass opportunities through session access
- Public-facing services without rate limiting
- Supply chain risks from unpinned CI/CD dependencies
- Container runs as root during build phase

### Remediation Timeline

**Quick Wins (24-72 hours):**
1. Remove `shell: true` from TUI local shell command execution
2. Add session ownership validation middleware
3. Implement rate limiting on gateway HTTP endpoints
4. Add explicit permissions blocks to GitHub Actions workflows
5. Pin GitHub Actions to commit SHAs

**Strategic Work (2-6 weeks):**
1. Comprehensive input validation framework
2. Command execution security wrapper/allowlist
3. SQL query builder with parameterized identifiers
4. Security headers middleware for all HTTP endpoints
5. Container security hardening (multi-stage builds, non-root throughout)
6. Automated security scanning in CI/CD pipeline

---

## Prioritized Findings Table

| Severity | Title | Component/Area | Location | Impact | Recommended Fix | Owner | ETA |
|----------|-------|----------------|----------|--------|-----------------|-------|-----|
| **CRITICAL** | Command Injection via TUI Shell | TUI/Shell | `src/tui/tui-local-shell.ts:96` | Arbitrary code execution | Remove `shell: true`, use spawn with args array | Backend | 24h |
| **HIGH** | Session IDOR - Unauthorized Access | Gateway/Auth | `src/gateway/http-utils.ts:50-62` | Access to arbitrary user sessions | Add session ownership validation middleware | Backend | 48h |
| **HIGH** | SQL Injection in Schema Ops | Database | `src/memory/memory-schema.ts:91-93` | Database manipulation, data theft | Use allowlist for table/column names | Backend | 48h |
| **HIGH** | Command Injection via Binary Path | Daemon | `src/daemon/program-args.ts:142` | Arbitrary command execution | Use `execFile` instead of `execSync`, validate input | Backend | 48h |
| **MEDIUM-HIGH** | Missing Rate Limiting | Gateway/API | All HTTP endpoints | DoS attacks, resource exhaustion | Implement express-rate-limit middleware | Backend | 72h |
| **MEDIUM-HIGH** | GitHub Actions - pull_request_target | CI/CD | `.github/workflows/auto-response.yml:6` | Malicious code execution in CI | Replace with `pull_request` event | DevOps | 48h |
| **MEDIUM-HIGH** | Unpinned GitHub Actions | CI/CD | `.github/workflows/*.yml` | Supply chain attacks | Pin all actions to commit SHAs | DevOps | 72h |
| **MEDIUM** | Browser Route IDOR | Browser/API | `src/browser/routes/agent.*.ts` | Unauthorized browser operations | Add targetId ownership validation | Backend | 1wk |
| **MEDIUM** | Media Endpoint Unprotected | Media/API | `src/media/server.ts:29` | Unauthorized media access | Add authentication middleware | Backend | 1wk |
| **MEDIUM** | Missing Security Headers | Gateway/HTTP | All HTTP responses | XSS, clickjacking, MIME sniffing | Add Helmet middleware | Backend | 1wk |
| **MEDIUM** | Keychain Shell Escaping | Credentials | `src/agents/cli-credentials.ts:122` | Command injection via account name | Use shellEscape utility | Backend | 72h |
| **LOW** | Dockerfile Root User During Build | Docker | `Dockerfile:1-32` | Elevated privileges during build | Use non-root user from start, multi-stage build | DevOps | 2wk |
| **LOW** | Eval Usage in Browser Tools | Browser | `src/browser/pw-tools-core.interactions.ts` | Code injection if input untrusted | Review necessity, add strict validation | Backend | 2wk |
| **INFO** | No SBOM Generated | Supply Chain | Build process | Unknown dependency tree | Add CycloneDX/SPDX generation | DevOps | 3wk |

---

## Detailed Findings

### Finding 1: Command Injection via TUI Local Shell

**Severity:** CRITICAL  
**CWE:** CWE-78 (OS Command Injection)  
**Location:** `src/tui/tui-local-shell.ts:96-97`

**Evidence:**
```typescript
// Line 78: cmd = user input from line.slice(1)
const cmd = line.slice(1);

// Lines 96-97: VULNERABLE - direct shell execution
const child = spawnCommand(cmd, {
  shell: true,  // UNSAFE: Shell injection possible
  cwd: getCwd(),
  env,
});
```

**Impact:**
An attacker with access to the TUI can execute arbitrary shell commands with the privileges of the moltbot process. This bypasses all security controls and could lead to:
- Complete system compromise
- Data exfiltration
- Privilege escalation
- Installation of backdoors
- Lateral movement within the network

**Likelihood:** HIGH  
Users routinely interact with the TUI shell interface. Any user who can access the TUI can exploit this.

**Remediation:**

1. **Remove `shell: true` option** - Use array-based command execution:
```typescript
// Parse command into program and arguments
const [program, ...args] = parseCommand(cmd);
const child = spawnCommand(program, args, {
  shell: false,  // Disable shell
  cwd: getCwd(),
  env,
});
```

2. **Add command allowlist** for sensitive operations:
```typescript
const ALLOWED_COMMANDS = ['ls', 'cd', 'pwd', 'cat', 'grep'];
const program = parseCommand(cmd)[0];
if (!ALLOWED_COMMANDS.includes(program)) {
  throw new Error(`Command '${program}' not allowed`);
}
```

3. **Use a secure shell wrapper** like `shell-escape` or implement proper argument escaping.

**Fix Diff:**
```diff
--- a/src/tui/tui-local-shell.ts
+++ b/src/tui/tui-local-shell.ts
@@ -93,7 +93,7 @@ export async function executeLocalShell(params: {
 
   const child = spawnCommand(cmd, {
-    shell: true,
+    shell: false,
     cwd: getCwd(),
     env,
   });
```

**References:**
- [OWASP Command Injection](https://owasp.org/www-community/attacks/Command_Injection)
- [Node.js child_process security](https://nodejs.org/en/docs/guides/security/#command-injection)

---

### Finding 2: Session IDOR - Unauthorized Session Access

**Severity:** HIGH  
**CWE:** CWE-639 (Authorization Bypass Through User-Controlled Key)  
**Location:** `src/gateway/http-utils.ts:50-62`, `src/gateway/server-methods/chat.ts`

**Evidence:**
```typescript
// src/gateway/http-utils.ts:50-62
export function parseRequestProfile(req: Request): { profileName: string; sessionKey: string } {
  const profileName = req.headers.get("X-Moltbot-Profile") ?? "default";
  
  // VULNERABILITY: Accepts arbitrary sessionKey from client
  const explicitSessionKey = req.headers.get("X-Moltbot-Session-Key");
  const sessionKey = explicitSessionKey ?? `${profileName}:${uuidv4()}`;
  
  return { profileName, sessionKey };
}

// No validation that the sessionKey belongs to the authenticated user
```

**Impact:**
An authenticated user can access sessions belonging to other users by providing their sessionKey in the `X-Moltbot-Session-Key` header. This enables:
- Reading other users' chat history and messages
- Manipulating other users' session state
- Impersonating other users in conversations
- Data theft and privacy violations

**Likelihood:** MEDIUM-HIGH  
Requires authentication but trivial to exploit if sessionKey format is predictable or can be enumerated.

**Remediation:**

1. **Add session ownership validation:**
```typescript
export function validateSessionOwnership(
  sessionKey: string, 
  authenticatedUser: string
): boolean {
  const session = loadSessionEntry(sessionKey);
  if (!session) return false;
  
  // Verify session belongs to authenticated user
  return session.owner === authenticatedUser;
}
```

2. **Implement middleware** to check ownership before processing requests:
```typescript
app.use((req, res, next) => {
  const { sessionKey } = parseRequestProfile(req);
  const user = req.user; // From auth middleware
  
  if (sessionKey && !validateSessionOwnership(sessionKey, user)) {
    return res.status(403).json({ error: "Forbidden: Session access denied" });
  }
  next();
});
```

3. **Use signed session tokens** instead of accepting raw sessionKeys from clients.

**Fix Diff:**
```diff
--- a/src/gateway/http-utils.ts
+++ b/src/gateway/http-utils.ts
@@ -47,6 +47,13 @@ export function parseAuthToken(req: Request): string | null {
   return null;
 }
 
+function validateSessionOwnership(sessionKey: string, user: string): boolean {
+  const session = loadSessionEntry(sessionKey);
+  if (!session || session.owner !== user) return false;
+  return true;
+}
+
 export function parseRequestProfile(req: Request): { profileName: string; sessionKey: string } {
+  const user = req.user; // Assuming auth middleware sets this
   const profileName = req.headers.get("X-Moltbot-Profile") ?? "default";
   const explicitSessionKey = req.headers.get("X-Moltbot-Session-Key");
+  
+  if (explicitSessionKey && !validateSessionOwnership(explicitSessionKey, user)) {
+    throw new Error("Forbidden: Invalid session access");
+  }
   
   const sessionKey = explicitSessionKey ?? `${profileName}:${uuidv4()}`;
```

**References:**
- [OWASP IDOR](https://owasp.org/www-community/attacks/Insecure_Direct_Object_Reference)
- [CWE-639](https://cwe.mitre.org/data/definitions/639.html)

---

### Finding 3: SQL Injection in Database Schema Operations

**Severity:** HIGH  
**CWE:** CWE-89 (SQL Injection)  
**Location:** `src/memory/memory-schema.ts:91-93`

**Evidence:**
```typescript
// Line 91 - VULNERABLE: Direct string interpolation
const rows = db.prepare(`PRAGMA table_info(${table})`).all() as Array<{ name: string }>;

// Line 93 - VULNERABLE: Multiple interpolations
db.exec(`ALTER TABLE ${table} ADD COLUMN ${column} ${definition}`);
```

**Impact:**
If `table`, `column`, or `definition` parameters are ever supplied from user input (directly or indirectly), an attacker could:
- Execute arbitrary SQL commands
- Drop tables or corrupt data
- Exfiltrate sensitive information
- Bypass authentication/authorization
- Escalate privileges

**Likelihood:** MEDIUM  
Currently called with hardcoded values, but the API design allows dynamic values. Future code changes could introduce user-controlled input.

**Remediation:**

1. **Use allowlist validation** for identifiers:
```typescript
const ALLOWED_TABLES = ['files', 'chunks'] as const;
const ALLOWED_COLUMNS = ['source', 'updated_at', 'content'] as const;

function ensureColumn(
  db: Database,
  table: typeof ALLOWED_TABLES[number],
  column: typeof ALLOWED_COLUMNS[number],
  definition: string
): void {
  // Validate table and column against allowlist
  if (!ALLOWED_TABLES.includes(table)) {
    throw new Error(`Invalid table name: ${table}`);
  }
  if (!ALLOWED_COLUMNS.includes(column)) {
    throw new Error(`Invalid column name: ${column}`);
  }
  
  // Validate definition is safe SQL type
  const SAFE_DEFINITIONS = /^(TEXT|INTEGER|REAL|BLOB)(\s+(NOT NULL|DEFAULT .+))*$/i;
  if (!SAFE_DEFINITIONS.test(definition)) {
    throw new Error(`Invalid column definition: ${definition}`);
  }
  
  // Now safe to use in query
  const rows = db.prepare(`PRAGMA table_info(${table})`).all();
  db.exec(`ALTER TABLE ${table} ADD COLUMN ${column} ${definition}`);
}
```

2. **Use SQL identifier quoting** to prevent injection:
```typescript
function quoteIdentifier(name: string): string {
  // SQLite uses double quotes for identifiers
  return `"${name.replace(/"/g, '""')}"`;
}

db.exec(`ALTER TABLE ${quoteIdentifier(table)} ADD COLUMN ${quoteIdentifier(column)} ${definition}`);
```

3. **Consider using an ORM** like Prisma or TypeORM that handles parameterization automatically.

**Fix Diff:**
```diff
--- a/src/memory/memory-schema.ts
+++ b/src/memory/memory-schema.ts
@@ -75,6 +75,20 @@ export function ensureRenamedTable(params: {
   }
 }
 
+const ALLOWED_TABLES = ['files', 'chunks'] as const;
+const ALLOWED_COLUMNS = ['source', 'updated_at', 'content'] as const;
+
+function validateIdentifier(value: string, allowed: readonly string[]): void {
+  if (!allowed.includes(value)) {
+    throw new Error(`Invalid identifier: ${value}`);
+  }
+}
+
 export function ensureColumn(
   db: Database,
-  table: string,
-  column: string,
+  table: typeof ALLOWED_TABLES[number],
+  column: typeof ALLOWED_COLUMNS[number],
   definition: string
 ): void {
+  validateIdentifier(table, ALLOWED_TABLES);
+  validateIdentifier(column, ALLOWED_COLUMNS);
+  
   const rows = db.prepare(`PRAGMA table_info(${table})`).all() as Array<{ name: string }>;
```

**References:**
- [OWASP SQL Injection](https://owasp.org/www-community/attacks/SQL_Injection)
- [SQLite Injection Prevention](https://www.sqlite.org/security.html)

---

### Finding 4: Command Injection via Binary Path Resolution

**Severity:** HIGH  
**CWE:** CWE-78 (OS Command Injection)  
**Location:** `src/daemon/program-args.ts:142`

**Evidence:**
```typescript
// Line 142: User-controlled 'binary' variable in shell command
const output = execSync(`${cmd} ${binary}`, { encoding: "utf8" }).trim();
// Example: If binary = "node; rm -rf /", executes: "which node; rm -rf /"
```

**Impact:**
Arbitrary command execution if the `binary` parameter can be influenced by user input. This could lead to:
- System compromise
- Data destruction
- Privilege escalation
- Service disruption

**Likelihood:** MEDIUM  
Depends on how `binary` parameter is constructed. If it comes from configuration files or user input, exploitation is straightforward.

**Remediation:**

1. **Use `execFile` instead of `execSync`:**
```typescript
import { execFileSync } from "node:child_process";

const output = execFileSync(cmd, [binary], { encoding: "utf8" }).trim();
```

2. **Validate binary name** against allowlist:
```typescript
const ALLOWED_BINARIES = ['node', 'npm', 'pnpm', 'bun'];
if (!ALLOWED_BINARIES.includes(binary)) {
  throw new Error(`Invalid binary: ${binary}`);
}
```

3. **Use path.basename()** to strip directory traversal:
```typescript
import path from "node:path";
const safeBinary = path.basename(binary);
const output = execFileSync(cmd, [safeBinary], { encoding: "utf8" }).trim();
```

**Fix Diff:**
```diff
--- a/src/daemon/program-args.ts
+++ b/src/daemon/program-args.ts
@@ -1,5 +1,6 @@
-import { execSync } from "node:child_process";
+import { execFileSync } from "node:child_process";
+import path from "node:path";
 
 function resolveBinaryPath(binary: string, cmd: string): string {
-  const output = execSync(`${cmd} ${binary}`, { encoding: "utf8" }).trim();
+  const safeBinary = path.basename(binary);
+  const output = execFileSync(cmd, [safeBinary], { encoding: "utf8" }).trim();
   return output;
 }
```

**References:**
- [Node.js Security Best Practices](https://nodejs.org/en/docs/guides/security/)
- [CWE-78](https://cwe.mitre.org/data/definitions/78.html)

---

### Finding 5: Missing Rate Limiting on Critical API Endpoints

**Severity:** MEDIUM-HIGH  
**CWE:** CWE-770 (Allocation of Resources Without Limits or Throttling)  
**Location:** All Gateway HTTP endpoints

**Evidence:**
```typescript
// src/gateway/server-http.ts - No rate limiting middleware found
// Critical endpoints without throttling:
// - /tools/invoke
// - /v1/chat/completions
// - /v1/responses
// - Hook endpoints
```

**Impact:**
Without rate limiting, attackers can:
- Launch DoS attacks by overwhelming the server with requests
- Brute force authentication tokens
- Exhaust server resources (CPU, memory, database connections)
- Increase infrastructure costs
- Degrade service for legitimate users

**Likelihood:** HIGH  
Public-facing API endpoints are easily discovered and targeted.

**Remediation:**

1. **Install rate limiting middleware:**
```bash
npm install express-rate-limit
```

2. **Add rate limiter to gateway:**
```typescript
import rateLimit from "express-rate-limit";

// Global rate limiter
const globalLimiter = rateLimit({
  windowMs: 15 * 60 * 1000, // 15 minutes
  max: 100, // Limit each IP to 100 requests per windowMs
  message: "Too many requests from this IP, please try again later.",
  standardHeaders: true,
  legacyHeaders: false,
});

// Stricter limiter for expensive operations
const chatLimiter = rateLimit({
  windowMs: 60 * 1000, // 1 minute
  max: 10, // 10 requests per minute
  message: "Rate limit exceeded for chat endpoint",
});

// Apply to routes
app.use(globalLimiter);
app.post("/v1/chat/completions", chatLimiter, chatHandler);
app.post("/tools/invoke", chatLimiter, toolsHandler);
```

3. **Implement token bucket algorithm** for more sophisticated rate limiting with burst allowance.

4. **Add monitoring** for rate limit violations to detect attacks.

**Fix Diff:**
```diff
--- a/src/gateway/server-http.ts
+++ b/src/gateway/server-http.ts
@@ -1,5 +1,16 @@
 import express from "express";
+import rateLimit from "express-rate-limit";
 
+const globalLimiter = rateLimit({
+  windowMs: 15 * 60 * 1000,
+  max: 100,
+  message: "Too many requests, please try again later.",
+});
+
+const chatLimiter = rateLimit({
+  windowMs: 60 * 1000,
+  max: 10,
+});
+
 export function createHttpServer() {
   const app = express();
+  app.use(globalLimiter);
   
-  app.post("/v1/chat/completions", chatHandler);
+  app.post("/v1/chat/completions", chatLimiter, chatHandler);
```

**References:**
- [Express Rate Limit](https://github.com/express-rate-limit/express-rate-limit)
- [OWASP Rate Limiting](https://cheatsheetseries.owasp.org/cheatsheets/Denial_of_Service_Cheat_Sheet.html)

---

### Finding 6: GitHub Actions - pull_request_target Security Risk

**Severity:** MEDIUM-HIGH  
**CWE:** CWE-829 (Inclusion of Functionality from Untrusted Control Sphere)  
**Location:** `.github/workflows/auto-response.yml:6`, `.github/workflows/labeler.yml:4`

**Evidence:**
```yaml
# .github/workflows/auto-response.yml
on:
  issues:
    types: [labeled]
  pull_request_target:  # DANGEROUS: Runs with write permissions on untrusted PR code
    types: [labeled]

permissions:
  issues: write
  pull-requests: write  # Over-scoped permissions
```

**Impact:**
The `pull_request_target` event runs in the context of the base repository with write permissions, even for PRs from forks. Malicious actors could:
- Close arbitrary issues/PRs via label manipulation
- Modify workflow behavior through malicious PRs
- Exfiltrate secrets if workflow handles them
- Poison CI/CD pipeline

**Likelihood:** MEDIUM  
Requires attacker to submit a malicious PR, which is straightforward for public repositories.

**Remediation:**

1. **Replace `pull_request_target` with `pull_request`:**
```yaml
on:
  issues:
    types: [labeled]
  pull_request:  # Safer: Runs with read-only permissions
    types: [labeled]
```

2. **Use minimal permissions:**
```yaml
permissions:
  issues: write  # Only if needed
  pull-requests: read  # Reduce to read-only where possible
```

3. **If `pull_request_target` is absolutely necessary:**
   - Add explicit approval requirement for first-time contributors
   - Use separate workflow for untrusted code
   - Never check out PR code in `pull_request_target` context

**Fix Diff:**
```diff
--- a/.github/workflows/auto-response.yml
+++ b/.github/workflows/auto-response.yml
@@ -3,7 +3,7 @@ name: Auto response
 on:
   issues:
     types: [labeled]
-  pull_request_target:
+  pull_request:
     types: [labeled]
 
 permissions:
   issues: write
-  pull-requests: write
+  pull-requests: read
```

**References:**
- [GitHub Security Lab - pull_request_target](https://securitylab.github.com/research/github-actions-preventing-pwn-requests/)
- [Keeping your GitHub Actions secure](https://docs.github.com/en/actions/security-guides/security-hardening-for-github-actions)

---

### Finding 7: Unpinned GitHub Actions

**Severity:** MEDIUM-HIGH  
**CWE:** CWE-494 (Download of Code Without Integrity Check)  
**Location:** `.github/workflows/ci.yml:135,251` and others

**Evidence:**
```yaml
# Using version tags instead of commit SHAs
- uses: actions/checkout@v4  # Should be @<commit-sha>
- uses: actions/setup-node@v4
- uses: oven-sh/setup-bun@v2
```

**Impact:**
Actions pinned to tags (e.g., `@v4`) can be updated by action maintainers, potentially introducing:
- Malicious code injection
- Supply chain attacks
- Compromised secrets
- CI/CD pipeline takeover

**Likelihood:** LOW-MEDIUM  
Requires compromise of action maintainer account or repository.

**Remediation:**

1. **Pin all actions to commit SHAs:**
```yaml
# Before
- uses: actions/checkout@v4

# After (example SHA)
- uses: actions/checkout@b4ffde65f46336ab88eb53be808477a3936bae11  # v4.1.1
```

2. **Add version comment** for maintainability:
```yaml
- uses: actions/checkout@b4ffde65f46336ab88eb53be808477a3936bae11  # v4.1.1
```

3. **Use Dependabot** to auto-update action SHAs (already configured in `.github/dependabot.yml`).

4. **Verify action integrity** with GitHub's action provenance.

**Fix Diff:**
```diff
--- a/.github/workflows/ci.yml
+++ b/.github/workflows/ci.yml
@@ -8,7 +8,7 @@ jobs:
     runs-on: blacksmith-4vcpu-ubuntu-2404
     steps:
-      - name: Checkout
-        uses: actions/checkout@v4
+      - name: Checkout
+        uses: actions/checkout@b4ffde65f46336ab88eb53be808477a3936bae11  # v4.1.1
         with:
           submodules: false
```

**References:**
- [GitHub Actions Security Best Practices](https://docs.github.com/en/actions/security-guides/security-hardening-for-github-actions#using-third-party-actions)
- [Pin actions to full commit SHA](https://docs.github.com/en/actions/security-guides/security-hardening-for-github-actions#using-third-party-actions)

---

### Finding 8: Browser Route IDOR Vulnerabilities

**Severity:** MEDIUM  
**CWE:** CWE-639 (Authorization Bypass Through User-Controlled Key)  
**Location:** `src/browser/routes/agent.*.ts`

**Evidence:**
```typescript
// src/browser/routes/agent.storage.ts:10-44
// Routes accept targetId/profileName from request without ownership verification
const resolvedContext = resolveProfileContext({
  targetId: params.targetId,  // User-controlled
  profileName: params.profileName,  // User-controlled
  // No validation that these belong to authenticated user
});
```

**Impact:**
Users can access browser operations for profiles/agents they don't own:
- Read cookies and storage from other users' profiles
- Manipulate browser state
- Access sensitive browser data
- Perform actions as other users

**Likelihood:** MEDIUM  
Server runs on loopback (127.0.0.1) which mitigates remote exploitation, but local access or SSRF could exploit this.

**Remediation:**

1. **Add ownership validation:**
```typescript
function validateProfileOwnership(
  profileName: string,
  targetId: string,
  user: string
): boolean {
  const profile = loadProfile(profileName);
  if (!profile || profile.owner !== user) return false;
  
  const target = resolveTarget(targetId);
  if (!target || target.profileName !== profileName) return false;
  
  return true;
}
```

2. **Apply validation in route handlers:**
```typescript
app.get("/cookies", async (req, res) => {
  const { targetId, profileName } = req.params;
  const user = req.user;
  
  if (!validateProfileOwnership(profileName, targetId, user)) {
    return res.status(403).json({ error: "Forbidden" });
  }
  
  // Process request
});
```

**Fix Diff:**
```diff
--- a/src/browser/routes/agent.storage.ts
+++ b/src/browser/routes/agent.storage.ts
@@ -7,6 +7,13 @@ import { resolveProfileContext } from "./agent.shared.js";
+function validateProfileOwnership(profileName: string, targetId: string, user: string): boolean {
+  const profile = loadProfile(profileName);
+  return profile?.owner === user;
+}
+
 export function registerStorageRoutes(app: Express) {
   app.get("/cookies", async (req, res) => {
     const params = parseRequestParams(req);
+    
+    if (!validateProfileOwnership(params.profileName, params.targetId, req.user)) {
+      return res.status(403).json({ error: "Forbidden" });
+    }
     
     const resolvedContext = resolveProfileContext(params);
```

**References:**
- [OWASP IDOR](https://owasp.org/www-community/attacks/Insecure_Direct_Object_Reference)

---

### Finding 9: Media Endpoint Without Authentication

**Severity:** MEDIUM  
**CWE:** CWE-306 (Missing Authentication for Critical Function)  
**Location:** `src/media/server.ts:29-35`

**Evidence:**
```typescript
// Media server serves files via path parameter without authentication
app.get("/media/:id", (req, res) => {
  const { id } = req.params;
  // Only validates path traversal, no auth check
  const filePath = resolveMediaPath(id);
  res.sendFile(filePath);
});
```

**Impact:**
If media IDs are predictable or leaked, any client can access stored media files without authentication:
- Unauthorized access to user-uploaded files
- Privacy violations
- Data exfiltration
- Information disclosure

**Likelihood:** MEDIUM  
Depends on ID generation algorithm. UUIDs provide good entropy, but if IDs are sequential or predictable, risk increases.

**Remediation:**

1. **Add authentication middleware:**
```typescript
import { authenticateToken } from "./auth.js";

app.get("/media/:id", authenticateToken, (req, res) => {
  const { id } = req.params;
  const filePath = resolveMediaPath(id);
  
  // Verify user has permission to access this media
  if (!canAccessMedia(req.user, id)) {
    return res.status(403).json({ error: "Forbidden" });
  }
  
  res.sendFile(filePath);
});
```

2. **Use signed URLs** with expiration:
```typescript
import crypto from "node:crypto";

function generateSignedMediaUrl(id: string, expiresIn: number): string {
  const expires = Date.now() + expiresIn;
  const signature = crypto
    .createHmac("sha256", process.env.MEDIA_SIGNING_KEY!)
    .update(`${id}:${expires}`)
    .digest("hex");
  
  return `/media/${id}?expires=${expires}&sig=${signature}`;
}
```

3. **Implement access control list** for media ownership.

**Fix Diff:**
```diff
--- a/src/media/server.ts
+++ b/src/media/server.ts
@@ -1,5 +1,6 @@
 import express from "express";
+import { authenticateToken, canAccessMedia } from "./auth.js";
 
 export function createMediaServer() {
   const app = express();
   
-  app.get("/media/:id", (req, res) => {
+  app.get("/media/:id", authenticateToken, (req, res) => {
     const { id } = req.params;
+    
+    if (!canAccessMedia(req.user, id)) {
+      return res.status(403).json({ error: "Forbidden" });
+    }
+    
     const filePath = resolveMediaPath(id);
     res.sendFile(filePath);
   });
```

**References:**
- [OWASP Authentication Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/Authentication_Cheat_Sheet.html)

---

### Finding 10: Missing Security Headers

**Severity:** MEDIUM  
**CWE:** CWE-693 (Protection Mechanism Failure)  
**Location:** All HTTP responses

**Evidence:**
```bash
# No security headers found in codebase:
$ grep -r "Content-Security-Policy\|X-Frame-Options\|Strict-Transport-Security" src/
# No results
```

**Impact:**
Missing security headers expose the application to:
- **XSS attacks** (no CSP)
- **Clickjacking** (no X-Frame-Options)
- **MIME sniffing attacks** (no X-Content-Type-Options)
- **Protocol downgrade attacks** (no HSTS)
- **Information disclosure** (no X-Powered-By removal)

**Likelihood:** MEDIUM  
While the application is designed for local use, missing headers increase attack surface for any network exposure.

**Remediation:**

1. **Install Helmet middleware:**
```bash
npm install helmet
```

2. **Apply to all Express/Hono apps:**
```typescript
import helmet from "helmet";

const app = express();

app.use(helmet({
  contentSecurityPolicy: {
    directives: {
      defaultSrc: ["'self'"],
      scriptSrc: ["'self'", "'unsafe-inline'"],
      styleSrc: ["'self'", "'unsafe-inline'"],
      imgSrc: ["'self'", "data:", "https:"],
      connectSrc: ["'self'"],
      fontSrc: ["'self'"],
      objectSrc: ["'none'"],
      mediaSrc: ["'self'"],
      frameSrc: ["'none'"],
    },
  },
  hsts: {
    maxAge: 31536000,
    includeSubDomains: true,
    preload: true,
  },
  frameguard: {
    action: "deny",
  },
  xssFilter: true,
  noSniff: true,
}));
```

3. **For Hono applications:**
```typescript
import { secureHeaders } from "hono/secure-headers";

app.use("*", secureHeaders());
```

**Fix Diff:**
```diff
--- a/src/gateway/server-http.ts
+++ b/src/gateway/server-http.ts
@@ -1,5 +1,6 @@
 import express from "express";
+import helmet from "helmet";
 
 export function createHttpServer() {
   const app = express();
+  
+  app.use(helmet({
+    contentSecurityPolicy: {
+      directives: {
+        defaultSrc: ["'self'"],
+        scriptSrc: ["'self'"],
+        styleSrc: ["'self'"],
+        imgSrc: ["'self'", "data:"],
+        connectSrc: ["'self'"],
+        objectSrc: ["'none'"],
+        frameSrc: ["'none'"],
+      },
+    },
+    hsts: {
+      maxAge: 31536000,
+      includeSubDomains: true,
+    },
+  }));
   
   // ... rest of server setup
 }
```

**References:**
- [OWASP Secure Headers Project](https://owasp.org/www-project-secure-headers/)
- [Helmet.js Documentation](https://helmetjs.github.io/)

---

### Finding 11: Keychain Command Shell Escaping

**Severity:** MEDIUM  
**CWE:** CWE-78 (OS Command Injection)  
**Location:** `src/agents/cli-credentials.ts:122-123`

**Evidence:**
```typescript
const secret = execSyncImpl(
  `security find-generic-password -s "Codex Auth" -a "${account}" -w`,
  // account = computeCodexKeychainAccount(codexHome)
  // If account contains shell metacharacters, could escape quotes
);
```

**Impact:**
If the `account` parameter contains shell metacharacters (backticks, $(), etc.), command injection is possible despite double quotes:
- Arbitrary command execution
- Keychain data exfiltration
- Privilege escalation

**Likelihood:** LOW-MEDIUM  
Depends on how `account` is computed. If it includes user-controlled paths or input, exploitation is possible.

**Remediation:**

1. **Use `execFileSync` with argument array:**
```typescript
import { execFileSync } from "node:child_process";

const secret = execFileSync(
  "security",
  ["find-generic-password", "-s", "Codex Auth", "-a", account, "-w"],
  { encoding: "utf8" }
).trim();
```

2. **Add shell escaping utility:**
```typescript
import { spawn } from "node:child_process";

function shellEscape(arg: string): string {
  // Escape for POSIX shell
  return `'${arg.replace(/'/g, "'\\''")}'`;
}

const secret = execSyncImpl(
  `security find-generic-password -s "Codex Auth" -a ${shellEscape(account)} -w`,
);
```

3. **Validate account format:**
```typescript
const ACCOUNT_REGEX = /^[a-zA-Z0-9_\-@.]+$/;
if (!ACCOUNT_REGEX.test(account)) {
  throw new Error("Invalid account format");
}
```

**Fix Diff:**
```diff
--- a/src/agents/cli-credentials.ts
+++ b/src/agents/cli-credentials.ts
@@ -1,4 +1,4 @@
-import { execSync } from "node:child_process";
+import { execFileSync } from "node:child_process";
 
 export function getKeychainSecret(account: string): string {
-  const secret = execSyncImpl(
-    `security find-generic-password -s "Codex Auth" -a "${account}" -w`,
+  const secret = execFileSync(
+    "security",
+    ["find-generic-password", "-s", "Codex Auth", "-a", account, "-w"],
+    { encoding: "utf8" }
   );
-  return secret.trim();
+  return secret.trim();
 }
```

**References:**
- [Node.js child_process security](https://nodejs.org/en/docs/guides/security/)

---

### Finding 12: Dockerfile Root User During Build

**Severity:** LOW  
**CWE:** CWE-250 (Execution with Unnecessary Privileges)  
**Location:** `Dockerfile:1-32`

**Evidence:**
```dockerfile
FROM node:22-bookworm

# Installs run as root (lines 3-17)
RUN curl -fsSL https://bun.sh/install | bash
ENV PATH="/root/.bun/bin:${PATH}"

# Build steps run as root (lines 24-31)
RUN pnpm install --frozen-lockfile
COPY . .
RUN pnpm build

# Only switches to non-root at the end (line 38)
USER node
```

**Impact:**
Running build steps as root increases attack surface:
- Build scripts execute with elevated privileges
- Compromised dependencies can modify system files
- Root-owned files may cause permission issues
- Defense-in-depth principle violated

**Likelihood:** LOW  
Requires malicious dependency or compromised build script.

**Remediation:**

1. **Use multi-stage build** with non-root user from start:
```dockerfile
FROM node:22-bookworm AS builder

# Create non-root user immediately
RUN groupadd -r moltbot && useradd -r -g moltbot moltbot
USER moltbot
WORKDIR /home/moltbot/app

# Install dependencies
COPY --chown=moltbot:moltbot package.json pnpm-lock.yaml ./
RUN pnpm install --frozen-lockfile

# Build
COPY --chown=moltbot:moltbot . .
RUN pnpm build

# Final stage
FROM node:22-bookworm-slim
RUN groupadd -r moltbot && useradd -r -g moltbot moltbot
USER moltbot
WORKDIR /home/moltbot/app

COPY --from=builder --chown=moltbot:moltbot /home/moltbot/app/dist ./dist
COPY --from=builder --chown=moltbot:moltbot /home/moltbot/app/node_modules ./node_modules

CMD ["node", "dist/index.js"]
```

2. **Use official Node images that include non-root user** (already does this partially).

3. **Scan container** with Trivy or Grype for vulnerabilities.

**Fix Diff:**
```diff
--- a/Dockerfile
+++ b/Dockerfile
-FROM node:22-bookworm
+FROM node:22-bookworm AS builder
 
-# Install Bun (required for build scripts)
-RUN curl -fsSL https://bun.sh/install | bash
-ENV PATH="/root/.bun/bin:${PATH}"
+RUN groupadd -r moltbot && useradd -r -g moltbot moltbot
+USER moltbot
+WORKDIR /home/moltbot/app
 
-RUN corepack enable
+# Install Bun as non-root user
+USER root
+RUN curl -fsSL https://bun.sh/install | bash && mv /root/.bun /opt/bun && chown -R moltbot:moltbot /opt/bun
+USER moltbot
+ENV PATH="/opt/bun/bin:${PATH}"
 
-WORKDIR /app
+# Copy files with proper ownership
+COPY --chown=moltbot:moltbot package.json pnpm-lock.yaml ./
+RUN pnpm install --frozen-lockfile
 
+COPY --chown=moltbot:moltbot . .
+RUN pnpm build
+
+# Final stage
+FROM node:22-bookworm-slim
+RUN groupadd -r moltbot && useradd -r -g moltbot moltbot
+USER moltbot
+WORKDIR /home/moltbot/app
+
+COPY --from=builder --chown=moltbot:moltbot /home/moltbot/app/dist ./dist
+COPY --from=builder --chown=moltbot:moltbot /home/moltbot/app/node_modules ./node_modules
+
-# Security hardening: Run as non-root user
-USER node
-
 CMD ["node", "dist/index.js"]
```

**References:**
- [Docker Security Best Practices](https://docs.docker.com/develop/security-best-practices/)
- [OWASP Docker Security](https://cheatsheetseries.owasp.org/cheatsheets/Docker_Security_Cheat_Sheet.html)

---

### Finding 13: Eval Usage in Browser Tools

**Severity:** LOW  
**CWE:** CWE-95 (Improper Neutralization of Directives in Dynamically Evaluated Code)  
**Location:** `src/browser/pw-tools-core.interactions.ts`

**Evidence:**
```typescript
var candidate = eval("(" + fnBody + ")");
```

**Impact:**
If `fnBody` ever contains untrusted input, arbitrary JavaScript code execution is possible in the browser context:
- Access to all browser APIs
- Data exfiltration
- Modification of page state
- Cookie/storage theft

**Likelihood:** LOW  
Current usage appears to be with trusted function definitions only. Risk increases if input source changes.

**Remediation:**

1. **Use Function constructor instead of eval:**
```typescript
// Safer alternative (still requires trust in input)
const candidate = new Function("return (" + fnBody + ")")();
```

2. **Use vm module for sandboxing:**
```typescript
import vm from "node:vm";

const context = vm.createContext({
  // Controlled environment
});
const candidate = vm.runInContext("(" + fnBody + ")", context);
```

3. **Validate fnBody** against allowlist or schema:
```typescript
const ALLOWED_FUNCTIONS = ["handleClick", "validateForm"];
if (!ALLOWED_FUNCTIONS.includes(fnBody)) {
  throw new Error("Untrusted function");
}
```

4. **Consider AST parsing** with libraries like `acorn` to validate JavaScript syntax before evaluation.

**Fix Diff:**
```diff
--- a/src/browser/pw-tools-core.interactions.ts
+++ b/src/browser/pw-tools-core.interactions.ts
@@ -1,5 +1,8 @@
+import vm from "node:vm";
+
 function parseFunctionBody(fnBody: string) {
-  var candidate = eval("(" + fnBody + ")");
+  const context = vm.createContext({ /* controlled environment */ });
+  var candidate = vm.runInContext("(" + fnBody + ")", context);
   return candidate;
 }
```

**References:**
- [MDN: eval is evil](https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/eval#never_use_eval!)
- [Node.js VM module](https://nodejs.org/api/vm.html)

---

## Dependency & Supply Chain Appendix

### Overview

The repository uses **pnpm** for Node.js dependency management with proper lockfile (`pnpm-lock.yaml`) and Dependabot configuration for automated updates.

### Dependency Security Status

✅ **Strong Points:**
- Lockfile present and committed (`pnpm-lock.yaml`)
- Dependabot configured for weekly updates (`.github/dependabot.yml`)
- Overrides specified for critical packages (`tar: 7.5.4`)
- Minimum release age set (`pnpm.minimumReleaseAge: 2880` = 2 days)
- Pre-commit hooks include secret detection

⚠️ **Concerns:**
- Some dependencies use `^` ranges (allows minor/patch updates)
- No SBOM (Software Bill of Materials) generated
- No automated vulnerability scanning in CI/CD
- `optionalDependencies` increase attack surface

### Known Vulnerable Dependencies

**Note:** Unable to run `npm audit` or `pnpm audit` during review. Recommend running:
```bash
pnpm audit --fix
```

### High-Risk Dependencies

Based on code review, these dependencies warrant special attention:

1. **`@whiskeysockets/baileys: 7.0.0-rc.9`**
   - Release candidate version (pre-release)
   - Core WhatsApp integration - high security impact
   - Recommendation: Monitor for stable release

2. **`ws: ^8.19.0`**
   - WebSocket library - attack surface for injection
   - Ensure latest patches applied

3. **`express: ^5.2.1`**
   - Express v5 is major version, ensure middleware compatibility
   - Critical for HTTP security

4. **`sqlite-vec: 0.1.7-alpha.2`**
   - Alpha version (pre-release)
   - Database component - data integrity risk

5. **`chromium-bidi: 13.0.1`**
   - Browser automation - RCE risk if misused
   - Keep updated for Chromium security patches

### Dependency Recommendations

1. **Pin critical dependencies** to exact versions (no `^` or `~`):
```json
{
  "dependencies": {
    "express": "5.2.1",
    "ws": "8.19.0"
  }
}
```

2. **Generate SBOM** in build process:
```bash
npm install -g @cyclonedx/cyclonedx-npm
cyclonedx-npm --output-file sbom.json
```

3. **Add vulnerability scanning** to CI:
```yaml
# .github/workflows/ci.yml
- name: Audit dependencies
  run: pnpm audit --audit-level moderate
```

4. **Enable GitHub Dependency Graph** and vulnerability alerts in repository settings.

5. **Review and minimize `optionalDependencies`:**
   - `@napi-rs/canvas`: Only needed for canvas operations
   - `node-llama-cpp`: Large ML dependency - consider externalization

### Supply Chain Security Controls

✅ **Implemented:**
- Lockfile commits (tamper detection)
- Dependabot for automated updates
- Pre-commit secret scanning
- Package manager verification (corepack)

❌ **Missing:**
- SBOM generation
- Dependency vulnerability scanning in CI
- Software provenance verification
- Binary artifact signing
- Automated security patch PRs

### SBOM Status

**Status:** NOT PRESENT

**Recommendation:** Generate SBOM using CycloneDX or SPDX:

```bash
# Install generator
npm install -g @cyclonedx/cyclonedx-npm

# Generate SBOM
cyclonedx-npm --output-format JSON --output-file sbom.json

# Add to package.json scripts
{
  "scripts": {
    "sbom:generate": "cyclonedx-npm --output-format JSON --output-file sbom.json"
  }
}
```

Include SBOM generation in release workflow:
```yaml
- name: Generate SBOM
  run: |
    npm install -g @cyclonedx/cyclonedx-npm
    cyclonedx-npm --output-format JSON --output-file dist/sbom.json
```

---

## CI/CD Hardening Checklist

### GitHub Actions Security

| Control | Status | Recommendation |
|---------|--------|----------------|
| **Token Permissions** | ⚠️ Partial | Add explicit `permissions:` blocks to all workflows |
| **Action Pinning** | ❌ Missing | Pin all actions to commit SHAs instead of tags |
| **pull_request_target** | ❌ Insecure | Replace with `pull_request` in auto-response.yml and labeler.yml |
| **Secrets Handling** | ✅ Good | Uses GitHub secrets properly, no plaintext credentials |
| **Branch Protection** | ⚠️ Unknown | Enable required reviews, status checks, signed commits |
| **CODEOWNERS** | ❌ Missing | Add CODEOWNERS file for security-critical paths |
| **Required Checks** | ⚠️ Unknown | Require passing CI before merge |
| **Artifact Verification** | ❌ Missing | Sign and verify build artifacts |
| **Cache Poisoning** | ⚠️ Unknown | Use cache key with lock file hash |

### Recommended Actions

1. **Add explicit permissions** to all workflows:
```yaml
# .github/workflows/ci.yml
name: CI

on: [push, pull_request]

permissions:
  contents: read  # Minimal default
  checks: write   # For test results
  pull-requests: write  # For PR comments (if needed)

jobs:
  build:
    runs-on: ubuntu-latest
    permissions:
      contents: read  # Override per-job if needed
    steps:
      # ...
```

2. **Pin all GitHub Actions:**
```yaml
- uses: actions/checkout@b4ffde65f46336ab88eb53be808477a3936bae11  # v4.1.1
- uses: actions/setup-node@60edb5dd545a775178f52524783378180af0d1f8  # v4.0.2
```

3. **Add CODEOWNERS file:**
```
# .github/CODEOWNERS

# Security-critical files require security team review
/src/gateway/auth.ts @security-team
/src/agents/cli-credentials.ts @security-team
/.github/workflows/ @security-team @devops-team
/Dockerfile @security-team @devops-team
```

4. **Enable branch protection** rules:
   - Require at least 1 approving review
   - Require status checks to pass (CI, linting)
   - Require signed commits
   - Require linear history
   - Include administrators in restrictions

5. **Add security scanning** to CI:
```yaml
- name: Run Trivy vulnerability scanner
  uses: aquasecurity/trivy-action@master
  with:
    scan-type: 'fs'
    scan-ref: '.'
    format: 'sarif'
    output: 'trivy-results.sarif'

- name: Upload Trivy results to GitHub Security
  uses: github/codeql-action/upload-sarif@v2
  with:
    sarif_file: 'trivy-results.sarif'
```

6. **Implement artifact signing:**
```yaml
- name: Sign artifacts
  run: |
    echo "$SIGNING_KEY" | base64 -d > signing.key
    gpg --import signing.key
    gpg --detach-sign --armor dist/moltbot.tar.gz
  env:
    SIGNING_KEY: ${{ secrets.GPG_SIGNING_KEY }}
```

### Secrets Management

✅ **Current Practices:**
- GitHub secrets used for sensitive values (`GH_APP_PRIVATE_KEY`)
- No hardcoded credentials in workflows
- Pre-commit hooks prevent secret commits

⚠️ **Improvements Needed:**
- Rotate secrets regularly (every 90 days)
- Use OIDC tokens instead of long-lived credentials
- Implement secret scanning with GitHub Advanced Security
- Add secret detection in PR reviews

---

## Security Controls Checklist

### Application Security Controls

| Control | Status | Details |
|---------|--------|---------|
| **Input Validation & Encoding** | ❌ Weak | Multiple injection vulnerabilities found (command, SQL) |
| **Output Encoding** | ⚠️ Partial | No XSS protection headers, but minimal user-generated content |
| **Authentication** | ✅ Strong | Token-based auth with timing-safe comparison |
| **Authorization** | ❌ Weak | IDOR vulnerabilities, missing ownership checks |
| **Session Management** | ⚠️ Partial | UUID-based but lacks ownership validation |
| **Cryptography** | ✅ Good | Uses crypto.randomBytes, proper hashing (SHA-256) |
| **Error Handling** | ⚠️ Unknown | Needs review for information disclosure |
| **Logging** | ⚠️ Unknown | Verify no sensitive data in logs |
| **Rate Limiting** | ❌ Missing | No throttling on any endpoints |
| **Security Headers** | ❌ Missing | CSP, HSTS, X-Frame-Options, X-Content-Type-Options all absent |

### Transport Security

| Control | Status | Details |
|---------|--------|---------|
| **TLS/HTTPS** | ⚠️ Partial | Optional HTTPS, no HSTS enforcement |
| **Certificate Validation** | ✅ Good | Default Node.js behavior |
| **Secure Protocols** | ✅ Good | Modern TLS versions |
| **HSTS** | ❌ Missing | No Strict-Transport-Security header |

### Data Protection

| Control | Status | Details |
|---------|--------|---------|
| **Encryption at Rest** | ⚠️ Unknown | Session storage encryption not verified |
| **Encryption in Transit** | ⚠️ Partial | HTTPS optional, WebSocket may be unencrypted |
| **Sensitive Data Handling** | ✅ Good | Credential files properly excluded from git |
| **PII Protection** | ⚠️ Unknown | Needs audit of logging/storage |
| **Secret Management** | ✅ Strong | Environment variables, no hardcoded secrets |

### Container Security

| Control | Status | Details |
|---------|--------|---------|
| **Non-root User** | ⚠️ Partial | Switches to `node` user at end, but build runs as root |
| **Minimal Base Image** | ✅ Good | Uses official node:22-bookworm |
| **Image Scanning** | ❌ Missing | No Trivy/Grype scanning in CI |
| **Read-only Filesystem** | ❌ Missing | Not enforced in Dockerfile |
| **Dropped Capabilities** | ❌ Missing | No `--cap-drop` in documentation |
| **Seccomp/AppArmor** | ❌ Missing | No security profiles defined |

### Dependency Management

| Control | Status | Details |
|---------|--------|---------|
| **Lockfile Committed** | ✅ Good | `pnpm-lock.yaml` present |
| **Dependency Scanning** | ❌ Missing | No `pnpm audit` in CI |
| **Automated Updates** | ✅ Good | Dependabot configured weekly |
| **SBOM Generation** | ❌ Missing | No Software Bill of Materials |
| **Version Pinning** | ⚠️ Partial | Some deps use `^` ranges |

### Development Security

| Control | Status | Details |
|---------|--------|---------|
| **Secret Scanning** | ✅ Strong | detect-secrets pre-commit hook |
| **Pre-commit Hooks** | ✅ Good | `.pre-commit-config.yaml` present |
| **Code Review** | ⚠️ Unknown | No CODEOWNERS file |
| **Security Testing** | ❌ Missing | No SAST/DAST in CI |
| **Dependency Review** | ✅ Good | Dependabot enabled |

### Monitoring & Incident Response

| Control | Status | Details |
|---------|--------|---------|
| **Security Logging** | ⚠️ Unknown | Audit log completeness not verified |
| **Anomaly Detection** | ❌ Missing | No rate limit violations tracking |
| **Alerting** | ⚠️ Unknown | Needs verification |
| **Incident Response Plan** | ✅ Good | SECURITY.md with reporting instructions |
| **Vulnerability Disclosure** | ✅ Good | Private email reporting available |

---

## Summary & Next Steps

### Critical Actions (Next 48 Hours)

1. ✅ **Remove `shell: true`** from `src/tui/tui-local-shell.ts`
2. ✅ **Add session ownership validation** in `src/gateway/http-utils.ts`
3. ✅ **Replace `pull_request_target`** in GitHub Actions workflows
4. ✅ **Add rate limiting** to gateway HTTP endpoints
5. ✅ **Use `execFileSync`** in `src/daemon/program-args.ts`

### High Priority (Next Week)

1. Pin all GitHub Actions to commit SHAs
2. Add SQL query allowlist validation in `src/memory/memory-schema.ts`
3. Implement security headers middleware (Helmet)
4. Add browser route ownership validation
5. Run `pnpm audit` and fix vulnerabilities

### Medium Priority (Next Month)

1. Create CODEOWNERS file for security-critical paths
2. Generate and publish SBOM
3. Add vulnerability scanning to CI/CD (Trivy/Grype)
4. Implement container multi-stage builds with non-root from start
5. Add authentication to media endpoints

### Strategic Initiatives (Ongoing)

1. Implement comprehensive input validation framework
2. Create secure command execution wrapper with allowlist
3. Add automated security testing (SAST/DAST)
4. Establish regular security audit schedule
5. Implement monitoring and alerting for security events

---

## Appendix: Security Resources

### Tools & Scanners
- **Secret Scanning:** detect-secrets (already configured)
- **Dependency Scanning:** `pnpm audit`, Snyk, Dependabot (configured)
- **Container Scanning:** Trivy, Grype
- **SAST:** Semgrep, CodeQL
- **SBOM Generation:** CycloneDX, SPDX

### References
- [OWASP Top 10](https://owasp.org/www-project-top-ten/)
- [CWE Top 25](https://cwe.mitre.org/top25/)
- [Node.js Security Best Practices](https://nodejs.org/en/docs/guides/security/)
- [Docker Security](https://docs.docker.com/develop/security-best-practices/)
- [GitHub Actions Security](https://docs.github.com/en/actions/security-guides)

### Contact
For questions about this security review, contact the Application Security team.

---

## Runtime Data Security & GDPR Compliance

### Overview

A comprehensive analysis of runtime data security and GDPR compliance has been documented separately. See **GDPR_DATA_PRIVACY.md** for the complete guide.

### Key Findings

#### Data Storage Analysis

**Data Types Stored:**
1. **Session Transcripts** - `~/.clawdbot/sessions/` (JSON, plaintext, indefinite retention)
2. **Memory Database** - `~/.clawdbot/memory/` (SQLite, unencrypted, indefinite retention)
3. **Configuration & Credentials** - `~/.clawdbot/config/` (JSON5, plaintext, indefinite retention)
4. **Logs** - Platform-dependent location (redacted by default)
5. **Third-Party Data** - Sent to AI providers (OpenAI, Anthropic, Google, AWS)

#### GDPR Compliance Status: ⚠️ **PARTIAL**

| GDPR Requirement | Status | Gap |
|------------------|--------|-----|
| Lawful Processing Basis | ⚠️ Partial | Requires organizational documentation |
| Data Minimization | ✅ Good | Only essential data collected |
| Storage Limitation | ❌ Missing | No automatic data expiration |
| Integrity & Confidentiality | ⚠️ Partial | No encryption at rest |
| Right to Access | ⚠️ Manual | No automated data export |
| Right to Erasure | ⚠️ Manual | Manual deletion required |
| Right to Data Portability | ❌ Missing | No export in machine-readable format |
| Data Breach Notification | ⚠️ Depends | Requires organizational procedure |

#### Critical Privacy & Data Security Gaps

1. **No Encryption at Rest** (HIGH)
   - Session transcripts stored in plaintext JSON
   - SQLite database unencrypted
   - Configuration files contain tokens in plaintext
   - **Impact:** Data breach if device/server compromised
   - **Remediation:** Implement full-disk encryption; consider application-level encryption

2. **Indefinite Data Retention** (HIGH)
   - No automatic cleanup of old sessions
   - Memory database persists forever
   - Violates GDPR storage limitation principle
   - **Impact:** Unnecessary data accumulation, compliance violations
   - **Remediation:** Implement automated data retention policies

3. **No Automated Data Export** (MEDIUM)
   - Users cannot easily request their data
   - GDPR data portability not supported
   - **Impact:** Manual fulfillment of user rights requests
   - **Remediation:** Implement `moltbot data export --user {id}` command

4. **Third-Party Data Transfers** (MEDIUM)
   - Data sent to USA-based AI providers
   - May lack adequate GDPR safeguards
   - **Impact:** International data transfer compliance issues
   - **Remediation:** Use DPAs, SCCs; prefer local models

5. **No Audit Trail** (MEDIUM)
   - Cannot track who accessed what data
   - No compliance logging
   - **Impact:** Cannot demonstrate accountability
   - **Remediation:** Implement audit logging for data access/deletion

#### Recommendations for GDPR Compliance

**Immediate Actions (Personal Use):**
1. ✅ Enable full-disk encryption on device
2. ✅ Review and accept being the data controller
3. ✅ Verify redaction is enabled: `moltbot config get logging.redactSensitive`
4. ⚠️ Implement manual data cleanup schedule (delete old sessions)
5. ⚠️ Prefer local AI models to minimize data transfers

**Required Actions (Organizational Use):**
1. 📋 Conduct Data Protection Impact Assessment (DPIA)
2. 📋 Appoint Data Protection Officer (DPO) if required
3. 📋 Document processing activities (Art. 30 ROPA)
4. 📋 Create privacy notice and user consent mechanism
5. 📋 Establish data breach response plan (72-hour notification)
6. 🔒 Enable HTTPS for gateway with valid certificates
7. 🔒 Implement automated data retention policies
8. 🔒 Sign Data Processing Agreements with AI providers
9. 🔒 Create procedures for user rights requests
10. 🔒 Conduct regular compliance audits

#### Sensitive Data Logging

**Current Protection:** ✅ STRONG

Moltbot automatically redacts sensitive information in logs:
- API keys: `sk-...`, `ghp-...`, `xox...`, `AIza...`, `npm_...`
- Passwords in env vars, JSON, CLI flags
- Bearer tokens and authorization headers  
- PEM private keys

**Configuration:**
```bash
# Verify redaction enabled (default: "tools")
moltbot config get logging.redactSensitive

# Options: "off" | "tools" | "all"
```

**Test Case:** `/home/runner/work/moltbot/moltbot/src/logging/redact.test.ts`

#### Data Subject Rights Implementation

| Right | GDPR Article | Current Support | Implementation Needed |
|-------|--------------|-----------------|----------------------|
| Access | Art. 15 | ⚠️ Manual | `moltbot data export --user {id}` |
| Erasure | Art. 17 | ⚠️ Manual | `moltbot data delete --user {id}` |
| Rectification | Art. 16 | ⚠️ Manual | `moltbot data rectify` command |
| Portability | Art. 20 | ❌ None | Export in JSON/CSV format |
| Object | Art. 21 | ✅ Good | Can block users immediately |
| Restrict | Art. 18 | ⚠️ Manual | Temporary user blocking |

**Manual Fulfillment:**
```bash
# Access: Find user's data
grep -r "{user-id}" ~/.clawdbot/sessions/
sqlite3 ~/.clawdbot/memory/*.sqlite "SELECT * FROM chunks WHERE content LIKE '%{user-id}%'"

# Erasure: Delete user's data
find ~/.clawdbot/sessions/ -name "*{user-id}*" -delete
sqlite3 ~/.clawdbot/memory/*.sqlite "DELETE FROM chunks WHERE content LIKE '%{user-id}%'"

# Portability: Export to JSON
cp ~/.clawdbot/sessions/{profile}/{session}.json /export/
```

#### Third-Party Data Processors

When using external AI providers, user data is transferred:

| Provider | Location | GDPR Status | Retention | Training Use |
|----------|----------|-------------|-----------|--------------|
| OpenAI | USA | DPA available | 30 days | No (zero retention) |
| Anthropic | USA | DPA available | Not stored | No |
| Google Gemini | USA/Global | DPA available | User-controlled | Depends on settings |
| AWS Bedrock | User region | BAA available | Not stored | No |
| Local Models | On-device | N/A | User-controlled | N/A |

**GDPR Requirements:**
- Sign Data Processing Agreement (DPA) with each provider
- Ensure Standard Contractual Clauses (SCCs) for USA transfers
- Document lawful basis for international transfers
- Notify users in privacy policy

**Recommendation:** Prefer local models (Ollama, llama.cpp) for GDPR-sensitive deployments to eliminate third-party data transfers.

#### Data Retention Policy Template

**Recommended Retention Periods:**

| Data Type | Personal Use | Organizational Use | Justification |
|-----------|--------------|-------------------|---------------|
| Session Transcripts | 1-3 years | 30-90 days | Based on business need |
| Memory Database | As needed | 6-12 months | Knowledge base utility |
| Logs | 90 days | 90 days (ops) / 1-2 years (security) | Operational/security requirements |
| User Credentials | Until deleted | Until offboarding + 30 days | Account access |

**Implementation (Cron Job):**
```bash
# Add to crontab: daily cleanup at 2 AM
0 2 * * * find ~/.clawdbot/sessions/ -name "*.json" -mtime +90 -delete
0 2 * * * sqlite3 ~/.clawdbot/memory/*.sqlite "DELETE FROM files WHERE updated_at < datetime('now', '-6 months')"
```

#### Documentation Artifacts Created

1. **GDPR_DATA_PRIVACY.md** - Comprehensive GDPR compliance guide including:
   - Data processing overview and legal basis
   - Detailed data inventory with sensitivity classifications
   - GDPR compliance status checklist
   - User rights fulfillment procedures
   - Data Protection Impact Assessment template
   - Recommended retention policies
   - Security measures and controls
   - FAQ for common compliance questions

2. **SECURITY.md (updated)** - Added runtime data security section covering:
   - What data is stored and where
   - Data retention and cleanup procedures
   - Sensitive data redaction configuration
   - GDPR compliance reference

### Summary & Next Steps for Data Privacy

**Critical Actions (Compliance-focused):**

1. **For Personal Users:**
   - Review GDPR_DATA_PRIVACY.md to understand your role as data controller
   - Enable full-disk encryption on your device
   - Set up periodic manual data cleanup
   - Consider using local models exclusively

2. **For Organizations:**
   - Conduct DPIA before deployment
   - Implement automated data retention (cron jobs)
   - Create user consent and privacy notice
   - Sign DPAs with AI providers
   - Establish data breach response plan
   - Train staff on GDPR compliance

3. **For Contributors:**
   - Implement encryption at rest for sensitive data
   - Add `moltbot data export/delete` commands
   - Create audit logging for compliance
   - Add automated retention policy options
   - Implement RBAC for multi-user deployments

**Risk Rating for Data Privacy:** **MEDIUM-HIGH**

While Moltbot has good defaults (local storage, redaction), the lack of encryption at rest, indefinite retention, and manual user rights fulfillment pose compliance risks for organizational deployments. Personal users have lower risk if using full-disk encryption.

---

### Contact
For questions about this security review, contact the Application Security team.

---

**End of Report**
