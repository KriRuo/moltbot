# Security & Privacy Documentation Index

This directory contains comprehensive security and privacy documentation for Moltbot. Use this index to find the information you need.

## Quick Navigation

### 🔒 For Security Issues
**File:** [SECURITY.md](SECURITY.md)  
**Read this if:** You found a security vulnerability, want to understand runtime data security, or need security best practices.

**Key sections:**
- Vulnerability reporting procedures
- Runtime data security overview
- Data storage locations and cleanup
- Sensitive data redaction
- Docker security hardening
- Node.js security requirements

---

### 🛡️ For Comprehensive Security Review
**File:** [SECURITY_REVIEW_2026-02-02.md](SECURITY_REVIEW_2026-02-02.md)  
**Read this if:** You need a complete security assessment, are evaluating Moltbot for your organization, or want to understand all security risks.

**Key sections:**
- Executive summary with top 5 risks
- 13 detailed vulnerability findings with fixes
- Prioritized findings table (Critical → Low)
- SQL injection, command injection, IDOR analysis
- GitHub Actions security review
- CI/CD hardening checklist
- Security controls checklist
- **Runtime data security & GDPR compliance section**

**Highlights:**
- 5 CRITICAL/HIGH vulnerabilities identified
- Each finding includes: CWE, evidence, impact, remediation, fix diffs
- Risk rating: **HIGH**
- Remediation timeline: 24h quick wins → 6 week strategic work

---

### 🇪🇺 For GDPR & Data Privacy
**File:** [GDPR_DATA_PRIVACY.md](GDPR_DATA_PRIVACY.md)  
**Read this if:** You need to understand GDPR compliance, handle user data requests, or deploy Moltbot in an organization processing EU resident data.

**Key sections:**
- GDPR compliance status (⚠️ PARTIAL)
- Complete data inventory (what, where, how long, encrypted?)
- User rights fulfillment procedures (access, erasure, portability, etc.)
- Data retention and cleanup
- Security measures (data at rest, in transit, in use)
- Recommendations for personal vs organizational use
- Data Protection Impact Assessment (DPIA) template
- Third-party processor table (AI providers)
- FAQ section

**Highlights:**
- 6 data types documented with locations and sensitivity
- Step-by-step user rights procedures with code examples
- GDPR status for 13 requirements (✅/⚠️/❌)
- Compliance gap analysis and remediation guidance

---

## Documentation Summary Table

| Document | Purpose | Target Audience | Length |
|----------|---------|-----------------|--------|
| **SECURITY.md** | Security policy, reporting, runtime data basics | All users | 2 pages |
| **SECURITY_REVIEW_2026-02-02.md** | Complete security assessment | Security teams, DevOps, Architects | 50+ pages |
| **GDPR_DATA_PRIVACY.md** | GDPR & privacy compliance guide | Legal, Compliance, DPOs, Admins | 26 pages |

---

## Common Questions Answered

### "Is Moltbot secure?"
→ See [SECURITY_REVIEW_2026-02-02.md](SECURITY_REVIEW_2026-02-02.md) for complete assessment. Summary: **5 critical vulnerabilities** need fixing (command injection, IDOR, SQL injection, missing rate limiting). Most affect developers more than end users.

### "Where is my data stored?"
→ See [GDPR_DATA_PRIVACY.md](GDPR_DATA_PRIVACY.md#data-we-collect--store). Summary: Locally in `~/.clawdbot/` - session files, SQLite database, config files. No data sent to Moltbot maintainers.

### "Is Moltbot GDPR compliant?"
→ See [GDPR_DATA_PRIVACY.md](GDPR_DATA_PRIVACY.md#gdpr-compliance-status). Summary: **⚠️ PARTIAL** - good for personal use, requires additional measures for organizational use (encryption, retention policies, DPAs).

### "How do I delete my data?"
→ See [SECURITY.md](SECURITY.md#manual-data-cleanup) or [GDPR_DATA_PRIVACY.md](GDPR_DATA_PRIVACY.md#data-retention--cleanup). Summary: `rm -rf ~/.clawdbot/` for complete wipe, or selective cleanup per documented procedures.

### "What happens when I use OpenAI/Anthropic?"
→ See [GDPR_DATA_PRIVACY.md](GDPR_DATA_PRIVACY.md#6-third-party-data-processors). Summary: Your messages are sent to AI provider servers. Review their privacy policies and data retention periods.

### "How do I report a security issue?"
→ See [SECURITY.md](SECURITY.md#reporting). Summary: Email `steipete@gmail.com` with reproduction steps and impact assessment.

### "What are the biggest security risks?"
→ See [SECURITY_REVIEW_2026-02-02.md](SECURITY_REVIEW_2026-02-02.md#top-5-risks). Summary:
1. Command injection in TUI shell (CRITICAL)
2. Session IDOR vulnerabilities (HIGH)
3. SQL injection in schema operations (HIGH)
4. Missing rate limiting (MEDIUM-HIGH)
5. GitHub Actions security issues (MEDIUM-HIGH)

---

## Compliance Checklists

### For Personal Users
- [ ] Read [SECURITY.md](SECURITY.md) - understand data storage
- [ ] Enable full-disk encryption on your device
- [ ] Review [GDPR_DATA_PRIVACY.md](GDPR_DATA_PRIVACY.md#for-self-hosted-personal-use) - personal use guidance
- [ ] Set up periodic data cleanup (optional)
- [ ] Verify redaction enabled: `moltbot config get logging.redactSensitive`
- [ ] Consider using local models to keep data on-device

### For Organizations
- [ ] Read [SECURITY_REVIEW_2026-02-02.md](SECURITY_REVIEW_2026-02-02.md) - complete security assessment
- [ ] Read [GDPR_DATA_PRIVACY.md](GDPR_DATA_PRIVACY.md#for-organizational-deployment) - compliance requirements
- [ ] Conduct Data Protection Impact Assessment (DPIA) - [template provided](GDPR_DATA_PRIVACY.md#data-protection-impact-assessment)
- [ ] Appoint Data Protection Officer (DPO) if required
- [ ] Sign Data Processing Agreements (DPAs) with AI providers
- [ ] Create privacy notice and user consent mechanism
- [ ] Implement automated data retention policies
- [ ] Enable HTTPS for gateway with valid certificates
- [ ] Establish data breach response plan (72-hour notification requirement)
- [ ] Create procedures for user rights requests (access, erasure, etc.)
- [ ] Conduct regular security audits
- [ ] Train staff on GDPR and security practices

### For Security Teams
- [ ] Review [SECURITY_REVIEW_2026-02-02.md](SECURITY_REVIEW_2026-02-02.md) - all findings
- [ ] Address 5 CRITICAL/HIGH vulnerabilities in [prioritized findings table](SECURITY_REVIEW_2026-02-02.md#prioritized-findings-table)
- [ ] Implement [CI/CD hardening checklist](SECURITY_REVIEW_2026-02-02.md#cicd-hardening-checklist)
- [ ] Review [security controls checklist](SECURITY_REVIEW_2026-02-02.md#security-controls-checklist)
- [ ] Add missing security controls (rate limiting, security headers, etc.)
- [ ] Implement encryption at rest for sensitive data
- [ ] Set up automated vulnerability scanning
- [ ] Create audit logging infrastructure

### For Developers/Contributors
- [ ] Read all three documents to understand security context
- [ ] Review [detailed findings](SECURITY_REVIEW_2026-02-02.md#detailed-findings) for code vulnerabilities
- [ ] Fix command injection vulnerabilities (TUI shell, program args, keychain)
- [ ] Fix IDOR vulnerabilities (session access, browser routes)
- [ ] Implement rate limiting on HTTP endpoints
- [ ] Add `moltbot data export/delete` commands for GDPR compliance
- [ ] Implement encryption at rest (SQLCipher for database)
- [ ] Add automated data retention policy options
- [ ] Implement audit logging for compliance
- [ ] Add RBAC for multi-user deployments

---

## Document History

| Date | Document | Version | Changes |
|------|----------|---------|---------|
| 2026-02-02 | SECURITY_REVIEW_2026-02-02.md | 1.0 | Initial comprehensive security review |
| 2026-02-02 | GDPR_DATA_PRIVACY.md | 1.0 | Initial GDPR compliance documentation |
| 2026-02-02 | SECURITY.md | Updated | Added runtime data security section |
| 2026-02-02 | SECURITY_DOCS.md | 1.0 | This index document |

---

## Additional Resources

### External References
- **OWASP Top 10:** https://owasp.org/www-project-top-ten/
- **CWE Top 25:** https://cwe.mitre.org/top25/
- **GDPR Full Text:** https://gdpr-info.eu/
- **GDPR Checklist:** https://gdpr.eu/checklist/
- **ICO Guide:** https://ico.org.uk/for-organisations/guide-to-data-protection/
- **Node.js Security:** https://nodejs.org/en/docs/guides/security/
- **Docker Security:** https://docs.docker.com/develop/security-best-practices/

### Project Documentation
- **Main Docs:** https://docs.molt.bot/
- **Gateway Security:** https://docs.molt.bot/gateway/security
- **Contributing:** CONTRIBUTING.md
- **Changelog:** CHANGELOG.md

---

## Contact

### Security Issues
- **Email:** steipete@gmail.com
- **Response Time:** Best effort

### Privacy/GDPR Questions
- For personal use: Review documentation above
- For organizational use: Designate your own DPO/privacy contact
- Moltbot maintainers do not act as data controllers/processors for your deployment

### Regulatory Authorities (for complaints)
- **EU DPA Directory:** https://edpb.europa.eu/about-edpb/about-edpb/members_en
- **UK ICO:** https://ico.org.uk
- **Germany BfDI:** https://www.bfdi.bund.de

---

**Last Updated:** February 2, 2026  
**Next Review:** August 2, 2026 (recommended 6-month cycle)
