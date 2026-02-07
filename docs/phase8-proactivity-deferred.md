# Phase 8: Proactivity Scheduler - Design Decision

## Status: DEFERRED TO POST-MVP

## Overview

The implementation plan calls for adding a "proactive assistant" feature with draft-first safety:

> **Principle: "Draft-first proactivity"**
> - Add a minimal **scheduler** that generates "draft suggestions".
> - Default: **auto-send only to self-chat** and only for safe categories
> - All other proactive outputs require explicit approval (UI action).

## Decision: Defer to Post-MVP

We have decided to **defer this feature** to post-MVP for the following reasons:

### Architectural Complexity

This feature requires:
1. **New service/package**: `apps/proactivity/` or `packages/proactivity/`
2. **Timer-based job runner**: Scheduling infrastructure
3. **Draft storage system**: New data model and persistence
4. **UI for draft approval**: Frontend changes to show/approve/dismiss drafts
5. **Policy engine**: Safe vs. unsafe categorization logic
6. **Self-chat detection**: Identifying which channels are "self"

These changes are substantial and touch multiple parts of the codebase.

### Security Considerations

Proactivity introduces new attack vectors:
- **Prompt injection via scheduled context**: An attacker could manipulate scheduled tasks
- **Unintended message sending**: Even with approval, bugs could lead to unwanted sends
- **Resource exhaustion**: Scheduler could be abused for DoS
- **Privacy concerns**: Proactive analysis of user data

These require careful design and testing beyond the scope of basic security hardening.

### Scope of Current Initiative

The current security hardening initiative focuses on:
- Container security (ports, users, socket isolation)
- Filesystem security (permissions)
- Authentication (token auth)
- Secrets management

Adding a major feature like proactivity scheduler exceeds the scope of "hardening existing functionality."

## Recommended Approach

### Phase 1: Design (Post-MVP)

1. **Threat model** the proactivity feature
   - What can go wrong?
   - What attack vectors exist?
   - How to mitigate?

2. **Architecture design**
   - Where does the scheduler run?
   - How are drafts stored?
   - What's the approval workflow?
   - How to ensure "self-only" default?

3. **User research**
   - Do users actually want proactive suggestions?
   - What categories are useful?
   - What's the right UX for approval?

### Phase 2: Implementation

1. **Core scheduler** (minimal)
   - Cron-like job runner
   - Draft generation only
   - No auto-send except self-chat

2. **Draft storage**
   - SQLite or JSON-based storage
   - Secure permissions (700/600)
   - Expiration policy

3. **UI for approval**
   - Show pending drafts
   - Approve/Dismiss buttons
   - Preview before sending

4. **Safety controls**
   - Default: self-chat only
   - Allowlist for other targets
   - Rate limiting
   - Audit logging

### Phase 3: Rollout

1. **Alpha testing** with self-chat only
2. **Beta testing** with allowlist
3. **Documentation** and best practices
4. **Gradual rollout** with monitoring

## Interim Solution

For users who want proactive functionality now:

### Manual Scheduled Tasks

Use system cron/systemd timers with the CLI:

```bash
# Create a daily summary script
cat > ~/daily-summary.sh << 'EOF'
#!/bin/bash
moltbot agent --message "Generate a daily summary and send it to my self-chat" --thinking low
EOF

chmod +x ~/daily-summary.sh

# Schedule with cron (runs at 8 AM daily)
crontab -e
# Add: 0 8 * * * /home/user/daily-summary.sh
```

**Safety**: 
- Fully controlled by user
- Explicit scripts = no prompt injection
- Standard Unix tools = well-understood security

### External Automation

Use tools like:
- **Zapier** / **IFTTT**: Trigger on events, call Moltbot API
- **n8n** / **Make**: Self-hosted workflow automation
- **GitHub Actions**: Scheduled workflows calling Moltbot

**Benefit**: 
- Proven automation tools
- Better audit trails
- Established security practices

## Success Criteria for Future Implementation

Before implementing Phase 8, we need:

1. ✅ **Core security hardening complete** (Phases 0-7)
2. ✅ **Threat model documented**
3. ✅ **Architecture design reviewed**
4. ✅ **User demand validated**
5. ✅ **Engineering resources allocated**
6. ✅ **Testing plan defined**

## See Also

- `v2_implementationplan` - Original plan including proactivity
- `docs/security-configuration.md` - Current security controls
- `docs/secrets-management.md` - Secrets best practices

## Recommendation

**Do not implement Phase 8 as part of the current security hardening effort.**

Instead:
1. Complete Phases 0-7 and 9 (security hardening + WhatsApp config)
2. Document Phase 8 as "Future Work"
3. Create a separate tracking issue for proactivity feature
4. Revisit after MVP is stable and secure

This approach ensures:
- ✅ Core security controls are in place
- ✅ Scope remains manageable
- ✅ Feature development is properly planned
- ✅ Security is not compromised for features
