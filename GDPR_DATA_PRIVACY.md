# GDPR & Data Privacy Compliance Guide

**Document Version:** 1.0  
**Last Updated:** February 2, 2026  
**Applies to:** Moltbot v2026.1.27-beta.1 and later

---

## Executive Summary

This document outlines Moltbot's data handling practices, GDPR compliance status, and recommendations for organizations using Moltbot to ensure compliance with data protection regulations including GDPR (EU), CCPA (California), and similar privacy laws.

**Important:** Moltbot is primarily designed for **self-hosted, personal use**. Organizations deploying Moltbot in environments where they process personal data of EU residents must implement additional controls beyond the default configuration.

---

## Table of Contents

1. [Data Processing Overview](#data-processing-overview)
2. [GDPR Compliance Status](#gdpr-compliance-status)
3. [Data We Collect & Store](#data-we-collect--store)
4. [Data Retention & Cleanup](#data-retention--cleanup)
5. [User Rights Under GDPR](#user-rights-under-gdpr)
6. [Security Measures](#security-measures)
7. [Recommendations for GDPR Compliance](#recommendations-for-gdpr-compliance)
8. [Data Protection Impact Assessment](#data-protection-impact-assessment)
9. [Contact & DPO Information](#contact--dpo-information)

---

## Data Processing Overview

### Processing Purpose

Moltbot processes personal data for the following purposes:

1. **Communication Management** - Routing and delivering messages across multiple channels (WhatsApp, Telegram, Discord, Slack, Signal, etc.)
2. **AI Agent Interaction** - Processing user queries and generating AI-powered responses
3. **Session Management** - Maintaining conversation context and history
4. **Knowledge Base** - Storing and retrieving information for semantic search
5. **Authentication** - Verifying user identity and managing access control

### Legal Basis for Processing

For personal (self-hosted) use:
- **Legitimate Interest** (GDPR Art. 6(1)(f)) - Processing necessary for the user's own purposes

For organizational use:
- **Consent** (GDPR Art. 6(1)(a)) - Explicit consent from users whose data is processed
- **Contract** (GDPR Art. 6(1)(b)) - Processing necessary for contract performance
- **Legal Obligation** (GDPR Art. 6(1)(c)) - Where required by law

### Data Controller vs Processor

- **Self-hosted deployments:** The person/organization running Moltbot is the **Data Controller**
- **Moltbot software:** Acts as a **Data Processor** executing controller's instructions
- **Third-party AI providers:** Are sub-processors if used (OpenAI, Anthropic, Google, etc.)

---

## GDPR Compliance Status

### Current Compliance Level: ⚠️ **PARTIAL**

Moltbot provides foundational privacy features but requires additional configuration and organizational policies for full GDPR compliance.

| GDPR Requirement | Status | Details |
|------------------|--------|---------|
| **Lawful Basis for Processing** | ⚠️ Partial | Requires organizational policy documentation |
| **Data Minimization** | ✅ Good | Only essential data collected |
| **Purpose Limitation** | ✅ Good | Clear processing purposes |
| **Storage Limitation** | ❌ Not Implemented | No automatic data expiration |
| **Integrity & Confidentiality** | ⚠️ Partial | Auth tokens unencrypted, TLS optional |
| **Accountability** | ⚠️ Partial | Logging present but no audit trail |
| **Right to Access** | ⚠️ Manual | No automated data export |
| **Right to Erasure** | ⚠️ Manual | Manual deletion required |
| **Right to Rectification** | ⚠️ Manual | No built-in correction mechanism |
| **Right to Data Portability** | ❌ Not Implemented | No export in machine-readable format |
| **Right to Object** | ✅ Good | Processing can be stopped anytime |
| **Privacy by Design** | ⚠️ Partial | Some defaults need hardening |
| **Data Breach Notification** | ⚠️ Depends | Requires organizational procedure |
| **Data Protection Impact Assessment** | ⚠️ Required | See section below |

---

## Data We Collect & Store

### 1. User Data

**Location:** `~/.clawdbot/config/config.json5`

**What we store:**
- Gateway authentication tokens/passwords
- Channel connection credentials (API tokens, bot tokens)
- User preferences and configuration
- Allowlists (phone numbers, usernames, email addresses)

**Sensitivity:** HIGH - Contains authentication credentials  
**Retention:** Indefinite (until manually deleted)  
**Encryption:** ❌ None (stored in plaintext)

**GDPR Classification:** Personal Data (identifiers, authentication data)

---

### 2. Message Data & Chat History

**Location:** `~/.clawdbot/sessions/{profileName}/{sessionKey}.json`

**What we store:**
- Full conversation transcripts (user messages + AI responses)
- User identifiers (phone numbers, usernames, chat IDs)
- Timestamps
- Delivery context (channel, thread information)
- Attached file metadata (but not file contents in transcript)

**Sensitivity:** HIGH - Contains personal communications  
**Retention:** Indefinite (until manually deleted)  
**Encryption:** ❌ None (stored in plaintext JSON)

**GDPR Classification:** Personal Data, potentially Special Categories if health/sensitive topics discussed

**Example transcript entry:**
```json
{
  "role": "user",
  "content": "What's the weather today?",
  "name": "John Doe",
  "timestamp": "2026-02-02T10:00:00Z"
}
```

---

### 3. Memory Database (Knowledge Base)

**Location:** `~/.clawdbot/memory/{agentId}.sqlite`

**What we store:**
- Text chunks from documents
- Vector embeddings for semantic search
- Source file paths and metadata
- Session transcript excerpts (if memory ingestion enabled)
- Timestamps of last access

**Sensitivity:** MEDIUM-HIGH (depends on content)  
**Retention:** Indefinite (until manually deleted or reset)  
**Encryption:** ❌ None (SQLite database unencrypted)

**GDPR Classification:** Personal Data if contains user information

**Database schema:**
- `files` table: File paths, sources, update times
- `chunks` table: Text content, embeddings, metadata
- `chunks_vec` table: Vector search index
- `chunks_fts` table: Full-text search index
- `embedding_cache` table: Cached embeddings to reduce API calls

---

### 4. Logs

**Location:** Application logs (location varies by platform)
- macOS: `~/Library/Logs/Moltbot/` and unified log system
- Linux/Docker: stdout/stderr or configured log file
- Windows: Event log or configured file

**What we store:**
- Application events and errors
- System operations and state changes
- Redacted tool outputs (sensitive tokens masked)
- User actions (command executions, tool invocations)

**Sensitivity:** MEDIUM (contains operational data, redacted credentials)  
**Retention:** Platform-dependent (log rotation configured by OS/user)  
**Encryption:** ❌ None (standard log files)

**Redaction Status:** ✅ Enabled by default (see `logging.redactSensitive` config)

**Patterns automatically redacted:**
- API keys: `sk-...`, `ghp_...`, `github_pat_...`, `xox...`, `AIza...`, `npm_...`
- Passwords in env vars, JSON, CLI flags
- Bearer tokens and authorization headers
- PEM private keys

---

### 5. Temporary Data

**What we store:**
- Browser session cookies (for automation)
- Screenshot captures (temporary files)
- Media processing buffers (in-memory or temp files)
- WebSocket connection state (in-memory)

**Sensitivity:** MEDIUM  
**Retention:** Session-based (cleared on disconnect) or temporary (deleted after processing)  
**Encryption:** ❌ None

**GDPR Classification:** Personal Data if contains user information

---

### 6. Third-Party Data Processors

When using external AI providers, user data is sent to:

| Provider | Data Sent | Privacy Policy | Data Location | Retention |
|----------|-----------|----------------|---------------|-----------|
| **OpenAI** | Messages, context | [Link](https://openai.com/policies/privacy-policy) | USA | 30 days (API) |
| **Anthropic** | Messages, context | [Link](https://www.anthropic.com/privacy) | USA | Not used for training |
| **Google (Gemini)** | Messages, context | [Link](https://policies.google.com/privacy) | USA/Global | Per account settings |
| **AWS Bedrock** | Messages, context | [Link](https://aws.amazon.com/privacy/) | User-selected region | Not used for training |
| **Local Models** | Messages, context | N/A (on-device) | Local only | User-controlled |

**GDPR Note:** Transfers to USA-based processors require appropriate safeguards (Standard Contractual Clauses, Privacy Shield successor, etc.)

---

## Data Retention & Cleanup

### Current Retention Policy

**Default Behavior:** 📌 **INDEFINITE RETENTION**

Moltbot does **not** automatically delete any stored data. All data persists indefinitely until manually removed.

### Manual Data Cleanup

#### 1. Delete Specific Session

```bash
# Remove session transcript file
rm ~/.clawdbot/sessions/{profile}/{sessionKey}.json

# Or use config if session store management exists
# (No built-in command currently available)
```

#### 2. Clear All Session History

```bash
# Remove all session files for a profile
rm -rf ~/.clawdbot/sessions/{profile}/

# Or clear all profiles
rm -rf ~/.clawdbot/sessions/
```

#### 3. Reset Memory Database

Use the memory management commands (if available):

```bash
# Reset entire memory index
moltbot memory reset --agent {agentId}

# Or manually delete the database
rm ~/.clawdbot/memory/{agentId}.sqlite
```

#### 4. Delete User Account from Channel

```bash
# Remove account credentials from config
moltbot channels remove {channel} --account {accountId}

# Note: This only removes credentials from config,
# does not delete historical message data
```

#### 5. Complete Data Wipe

```bash
# ⚠️ WARNING: Irreversible - deletes ALL Moltbot data
rm -rf ~/.clawdbot/
```

### Recommended Retention Policies

For GDPR compliance, implement automated retention policies:

**Personal Use:**
- Session transcripts: 1-3 years or based on usage
- Memory database: Regular pruning of old entries
- Logs: 90 days (standard log rotation)

**Organizational Use:**
- Session transcripts: 30-90 days (business requirement dependent)
- Memory database: 6-12 months with documented retention justification
- Logs: 90 days for operational, 1-2 years for security logs
- User accounts: Delete within 30 days of departure

**Implementation:** Create cron jobs or scheduled tasks to purge old data:

```bash
# Example: Delete sessions older than 90 days
find ~/.clawdbot/sessions/ -type f -name "*.json" -mtime +90 -delete

# Example: Clear old memory entries (requires custom script)
sqlite3 ~/.clawdbot/memory/{agentId}.sqlite \
  "DELETE FROM files WHERE updated_at < datetime('now', '-6 months')"
```

---

## User Rights Under GDPR

### 1. Right to Access (Art. 15)

**Request:** User wants to know what data is stored about them

**Current Implementation:** ⚠️ Manual

**How to fulfill:**
1. Identify session files containing user's identifier:
   ```bash
   grep -r "{user-phone-or-id}" ~/.clawdbot/sessions/
   ```

2. Extract user's data from database:
   ```bash
   sqlite3 ~/.clawdbot/memory/{agentId}.sqlite \
     "SELECT * FROM chunks WHERE content LIKE '%{user-identifier}%'"
   ```

3. Export logs containing user activity:
   ```bash
   grep "{user-identifier}" /path/to/logs/*.log
   ```

4. Provide in readable format (JSON, PDF, or plain text)

**Recommendation:** Implement `moltbot data export --user {identifier}` command

---

### 2. Right to Erasure / "Right to be Forgotten" (Art. 17)

**Request:** User wants their data deleted

**Current Implementation:** ⚠️ Manual

**How to fulfill:**
1. Delete user's session transcripts:
   ```bash
   find ~/.clawdbot/sessions/ -name "*{user-identifier}*" -delete
   ```

2. Remove from memory database:
   ```bash
   sqlite3 ~/.clawdbot/memory/{agentId}.sqlite \
     "DELETE FROM chunks WHERE content LIKE '%{user-identifier}%'"
   sqlite3 ~/.clawdbot/memory/{agentId}.sqlite \
     "DELETE FROM files WHERE path LIKE '%{user-identifier}%'"
   ```

3. Remove from allowlists/config:
   ```bash
   moltbot config set channels.{channel}.allowFrom "[]"
   ```

4. Notify AI provider if data was sent externally (varies by provider)

5. Document deletion in compliance log

**Recommendation:** Implement `moltbot data delete --user {identifier} --confirm` command

---

### 3. Right to Rectification (Art. 16)

**Request:** User wants incorrect data corrected

**Current Implementation:** ⚠️ Manual

**How to fulfill:**
1. Locate incorrect data in session files or database
2. Edit JSON files manually or use database UPDATE queries
3. Document correction in audit log

**Recommendation:** Implement `moltbot data rectify --session {id} --field {field} --value {new-value}`

---

### 4. Right to Data Portability (Art. 20)

**Request:** User wants their data in machine-readable format

**Current Implementation:** ❌ Not Implemented

**How to fulfill manually:**
1. Export session transcripts (already in JSON format):
   ```bash
   cp ~/.clawdbot/sessions/{profile}/*.json /export/directory/
   ```

2. Export memory database:
   ```bash
   sqlite3 ~/.clawdbot/memory/{agentId}.sqlite .dump > memory_export.sql
   ```

3. Package in standard format (JSON, CSV, XML)

**Recommendation:** Implement `moltbot data export --format json --user {identifier} --output export.json`

---

### 5. Right to Object (Art. 21)

**Request:** User objects to processing of their data

**Current Implementation:** ✅ Can be stopped immediately

**How to fulfill:**
1. Block user in allowlist:
   ```bash
   moltbot config set channels.{channel}.allowFrom "[]"
   # Or use blockFrom if supported
   ```

2. Stop gateway to cease all processing:
   ```bash
   moltbot gateway stop
   ```

3. Document objection and response in compliance log

---

### 6. Right to Restrict Processing (Art. 18)

**Request:** User wants processing temporarily restricted

**Current Implementation:** ⚠️ Manual

**How to fulfill:**
1. Disable specific channel connection
2. Block user from allowlist temporarily
3. Archive data without deleting
4. Document restriction period

---

## Security Measures

### Runtime Data Security

#### 1. Data at Rest

**Current Protection:**
- ⚠️ No encryption for session files
- ⚠️ No encryption for SQLite database
- ⚠️ No encryption for configuration files
- ✅ File system permissions (Unix file modes)

**Recommendations:**
- Enable full-disk encryption (FileVault, LUKS, BitLocker)
- Use encrypted volumes for `~/.clawdbot/` directory
- Consider database encryption (SQLCipher for SQLite)
- Encrypt sensitive config fields with master password

#### 2. Data in Transit

**Current Protection:**
- ✅ HTTPS optional for gateway (when enabled with TLS cert)
- ✅ TLS for third-party API connections (OpenAI, Anthropic, etc.)
- ⚠️ WebSocket may be unencrypted (depends on config)
- ✅ Channel-specific encryption (WhatsApp E2E, Signal E2E)

**Recommendations:**
- Always enable HTTPS for gateway in production
- Use Tailscale or VPN for remote access
- Enforce TLS 1.3 minimum
- Implement certificate pinning for critical connections

#### 3. Data in Use (Memory)

**Current Protection:**
- ✅ Process isolation (OS-level)
- ⚠️ In-memory session cache (45-second TTL)
- ⚠️ No memory encryption
- ⚠️ Core dumps may contain sensitive data

**Recommendations:**
- Disable core dumps in production: `ulimit -c 0`
- Use memory-locked pages for sensitive data (requires elevated privileges)
- Clear sensitive variables after use
- Enable ASLR (Address Space Layout Randomization)

#### 4. Authentication & Access Control

**Current Protection:**
- ✅ Token-based authentication with timing-safe comparison
- ✅ Password authentication option
- ✅ Tailscale integration for network-level auth
- ⚠️ No multi-factor authentication (MFA)
- ⚠️ No role-based access control (RBAC)

**Recommendations:**
- Implement MFA for gateway access
- Add RBAC for multi-user deployments
- Enforce strong password policies
- Implement session expiration and renewal

#### 5. Logging & Monitoring

**Current Protection:**
- ✅ Sensitive data redaction enabled by default
- ✅ Structured logging with tslog
- ⚠️ No centralized log management
- ⚠️ No real-time security monitoring

**Recommendations:**
- Use centralized log management (ELK, Splunk, Loki)
- Implement security event monitoring
- Set up alerts for suspicious activity
- Regular log review and analysis

---

## Recommendations for GDPR Compliance

### For Self-Hosted Personal Use

1. **✅ Acknowledge you are the data controller**
2. **✅ Document your processing purposes** (e.g., personal assistant)
3. **✅ Enable data redaction** (default, verify: `logging.redactSensitive: "tools"`)
4. **✅ Use local models** where possible (to avoid data transfers)
5. **⚠️ Enable full-disk encryption** on your device
6. **⚠️ Implement data retention policy** (delete old sessions periodically)
7. **⚠️ Review third-party processors** (understand AI provider privacy policies)

### For Organizational Deployment

#### Immediate Actions (Required)

1. **📋 Conduct Data Protection Impact Assessment (DPIA)** - See section below
2. **📋 Appoint Data Protection Officer (DPO)** if required (org with >250 employees or large-scale sensitive data processing)
3. **📋 Document processing activities** (GDPR Art. 30 Record of Processing Activities)
4. **📋 Review AI provider Data Processing Agreements (DPAs)**
5. **📋 Implement user consent mechanism** for data collection
6. **📋 Create privacy notice** explaining data practices
7. **📋 Establish data breach response plan** (72-hour notification requirement)

#### Technical Implementations (High Priority)

1. **🔒 Enable HTTPS** for all gateway connections:
   ```bash
   moltbot gateway run --tls-cert /path/to/cert.pem --tls-key /path/to/key.pem
   ```

2. **🔒 Encrypt data at rest:**
   - Enable full-disk encryption on servers
   - Use encrypted database (SQLCipher)
   - Encrypt backups

3. **🔒 Implement automated data retention:**
   ```bash
   # Add to cron
   0 2 * * * find ~/.clawdbot/sessions/ -name "*.json" -mtime +90 -delete
   ```

4. **🔒 Add audit logging:**
   - Log all data access requests
   - Log data deletions
   - Log user consent changes

5. **🔒 Implement data export functionality:**
   ```typescript
   // Pseudocode for recommended feature
   async function exportUserData(userId: string): Promise<ExportData> {
     return {
       sessions: await getSessionsByUser(userId),
       memoryEntries: await getMemoryEntriesByUser(userId),
       logs: await getLogsByUser(userId),
       format: "JSON",
       exportDate: new Date().toISOString()
     };
   }
   ```

#### Policy & Documentation (Required)

1. **📄 Privacy Policy** - Explain:
   - What data is collected and why
   - How long it's retained
   - Who has access
   - User rights and how to exercise them
   - Data breach notification procedures

2. **📄 Terms of Service** - Cover:
   - Acceptable use
   - Data ownership
   - Liability limitations
   - Termination procedures

3. **📄 User Consent Forms** - Obtain explicit consent for:
   - Data collection and processing
   - Data transfers to third parties (AI providers)
   - Marketing communications (if applicable)

4. **📄 Data Processing Agreement (DPA)** - If processing data on behalf of others

5. **📄 Employee Training** - Ensure staff understand:
   - GDPR principles
   - User rights
   - Data handling procedures
   - Incident response

#### Organizational Controls (Required)

1. **🔐 Access Control:**
   - Implement least-privilege access
   - Regular access reviews
   - Offboarding procedures

2. **🔐 Data Classification:**
   - Identify sensitive data types
   - Apply appropriate protections
   - Label data accordingly

3. **🔐 Vendor Management:**
   - Review AI provider compliance
   - Ensure DPAs are signed
   - Monitor for breaches

4. **🔐 Regular Audits:**
   - Annual GDPR compliance review
   - Penetration testing
   - Vulnerability assessments

---

## Data Protection Impact Assessment (DPIA)

**Required when:** Processing personal data that may result in high risk to individuals' rights and freedoms (GDPR Art. 35)

### DPIA Template for Moltbot Deployment

#### 1. Description of Processing

- **Purpose:** [Describe why you're using Moltbot - e.g., "Internal employee helpdesk automation"]
- **Data types:** [List data types - e.g., "Employee names, email addresses, support queries"]
- **Data subjects:** [Who - e.g., "Employees, contractors"]
- **Categories:** [Special categories? - e.g., "No special categories" or "May include health information"]
- **Volume:** [Scale - e.g., "500 employees, 1000 messages/day"]
- **Retention:** [How long - e.g., "90 days"]

#### 2. Necessity & Proportionality

- **Necessity:** [Why is this data needed? Can you use less?]
- **Adequacy:** [Is this data sufficient for the purpose?]
- **Relevance:** [Is all data relevant to the purpose?]
- **Limitation:** [Are you collecting only what's needed?]

#### 3. Risks to Individuals

| Risk | Likelihood | Severity | Impact |
|------|------------|----------|--------|
| Unauthorized access to chat history | Medium | High | Privacy breach, reputational damage |
| Data breach of credentials | Low | Critical | Account takeover, data loss |
| Third-party data sharing | Medium | Medium | Privacy concerns, compliance violations |
| Indefinite data retention | High | Medium | Privacy violation, GDPR non-compliance |

#### 4. Compliance Measures

- **Data minimization:** [What steps are taken?]
- **Security measures:** [List technical/organizational measures]
- **User rights:** [How are rights fulfilled?]
- **Data transfers:** [Are there international transfers? Safeguards?]

#### 5. Consultation

- **DPO consulted:** [Yes/No, Date]
- **Data subjects consulted:** [Yes/No, Method]
- **Regulators consulted:** [If required]

#### 6. Approval

- **Assessor:** [Name, Role, Date]
- **Approver:** [Senior Management, Date]
- **Next review:** [Date - typically annually]

---

## Contact & DPO Information

### For Security Issues

- **Security Email:** steipete@gmail.com
- **Response Time:** Best effort (not a commercial product)
- **PGP Key:** [If available]

### For Privacy/GDPR Inquiries

For organizations deploying Moltbot:
- Designate your own DPO or privacy contact
- Document contact information in your privacy policy
- Provide contact mechanism for user rights requests

**Note:** Moltbot is open-source software. The maintainers do not act as data controllers or processors for your deployment. You are responsible for GDPR compliance in your use of the software.

### Regulatory Authorities

**EU Data Protection Authorities:** [List by country](https://edpb.europa.eu/about-edpb/about-edpb/members_en)

**Example Contacts:**
- **UK:** Information Commissioner's Office (ICO) - https://ico.org.uk
- **Germany:** Federal Commissioner for Data Protection and Freedom of Information - https://www.bfdi.bund.de
- **France:** Commission Nationale de l'Informatique et des Libertés (CNIL) - https://www.cnil.fr
- **Ireland:** Data Protection Commission - https://www.dataprotection.ie

---

## Frequently Asked Questions

### Q: Is Moltbot GDPR compliant out of the box?

**A:** No. Moltbot provides privacy-friendly defaults (data redaction, local storage) but **requires additional configuration and organizational policies** for full GDPR compliance. See the Recommendations section above.

### Q: Where is my data stored?

**A:** Locally on your device/server in `~/.clawdbot/` directory. If using cloud AI providers (OpenAI, Anthropic, etc.), message data is sent to their servers for processing. Use local models to keep all data on-device.

### Q: Is data encrypted?

**A:** Not by default. Session files, databases, and config files are stored unencrypted. You must enable full-disk encryption at the OS level or implement application-level encryption.

### Q: How do I delete all data?

**A:** Run `rm -rf ~/.clawdbot/` to remove all local data. For cloud AI providers, follow their data deletion procedures (varies by provider).

### Q: Can I use Moltbot for EU users?

**A:** Yes, but you must implement GDPR compliance measures including: data processing agreements with AI providers, user consent mechanisms, data retention policies, and documented procedures for user rights requests.

### Q: Does Moltbot send data to third parties?

**A:** Only when you configure external AI providers (OpenAI, Anthropic, Google, AWS). Local models keep all data on your device. Channel integrations (WhatsApp, Telegram, etc.) communicate with those platforms' APIs.

### Q: How do I export a user's data (GDPR data portability)?

**A:** Currently manual. Copy session JSON files from `~/.clawdbot/sessions/` and export database with SQLite dump. We recommend implementing an automated export command.

### Q: What happens if there's a data breach?

**A:** You (the data controller) are responsible for breach notification under GDPR (72 hours to authority, without undue delay to affected individuals). Implement monitoring and incident response procedures.

### Q: Can I disable logging?

**A:** Yes, configure `logging.level` to higher level or disable specific loggers. Note: This may impair debugging. Sensitive data redaction is enabled by default.

### Q: Is Moltbot certified for ISO 27001, SOC 2, etc.?

**A:** No. Moltbot is open-source software, not a managed service. Organizations must conduct their own compliance assessments and certifications.

---

## Change Log

| Version | Date | Changes |
|---------|------|---------|
| 1.0 | 2026-02-02 | Initial GDPR compliance documentation |

---

## Additional Resources

- **GDPR Full Text:** https://gdpr-info.eu/
- **GDPR Checklist:** https://gdpr.eu/checklist/
- **ICO Guide:** https://ico.org.uk/for-organisations/guide-to-data-protection/
- **EDPB Guidelines:** https://edpb.europa.eu/our-work-tools/general-guidance_en
- **Data Protection by Design:** https://edpb.europa.eu/our-work-tools/our-documents/guidelines/guidelines-42019-article-25-data-protection-design-and_en

---

**Disclaimer:** This document provides general guidance and does not constitute legal advice. Organizations should consult qualified legal counsel to ensure compliance with applicable data protection laws.
