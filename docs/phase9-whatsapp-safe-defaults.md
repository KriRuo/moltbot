# Phase 9: WhatsApp Safe Defaults - Configuration Guide

## Overview

This document outlines safe configuration defaults for WhatsApp to prevent:
- Responding to random group chatter
- Accepting DMs from strangers
- Prompt injection via group messages
- Spam and abuse

## WhatsApp Security Architecture

WhatsApp channels in Moltbot have several security layers:

### 1. DM Policy

Controls who can send direct messages to your bot:

**Options:**
- `pairing` - Requires explicit pairing (safest, **recommended**)
- `allowlist` - Only allowlisted phone numbers (safe)
- `open` - Anyone can DM (dangerous, **not recommended**)

### 2. Group Policy

Controls how the bot responds in groups:

**Options:**
- `mention-only` - Only responds when mentioned (safest)
- `allowlist` - Only responds in allowlisted groups
- `deny` - Never responds in groups
- `open` - Responds to all group messages (dangerous)

### 3. Allowlists

Explicit lists of allowed phone numbers or group JIDs:

- `dmAllowlist` - Phone numbers that can DM
- `groupAllowlist` - Groups where bot will respond

## Recommended Configuration

### Configuration File

Location: `~/.moltbot/moltbot.json`

```json
{
  "channels": {
    "whatsapp": {
      "enabled": true,
      "dmPolicy": "pairing",
      "groupPolicy": "mention-only",
      "dmAllowlist": [],
      "groupAllowlist": [],
      "requireMentionInGroups": true
    }
  }
}
```

### Explanation

**`dmPolicy: "pairing"`**
- Users must explicitly pair with the bot before DMing
- Prevents random people from sending messages
- Protects against spam and prompt injection

**`groupPolicy: "mention-only"`**
- Bot only responds when @mentioned in groups
- Prevents reacting to random group chatter
- Reduces noise and potential prompt injection

**`dmAllowlist: []`**
- Start with empty allowlist
- Add numbers manually as needed
- Keep the list minimal

**`groupAllowlist: []`**
- Start with empty allowlist
- Add specific groups where bot should be active
- Review regularly

**`requireMentionInGroups: true`**
- Enforces @mention requirement in all groups
- Even allowlisted groups need @mention
- Maximum safety

## Pairing Workflow

With `dmPolicy: "pairing"`, users must pair before DMing:

### 1. User Requests Pairing

User sends a special pairing message:
```
/pair
```

### 2. Bot Sends Pairing Code

Bot generates a unique pairing code and sends it to the user's registered channel (e.g., web UI).

### 3. User Confirms Pairing

User enters the pairing code:
```
/pair <code>
```

### 4. Bot Confirms

Bot confirms pairing and adds user to allowlist:
```
✓ Paired! You can now send me direct messages.
```

## Group Configuration

### Safe Group Setup

1. **Only add bot to groups you control**
   - Don't add to public groups
   - Verify all group members

2. **Enable mention-only mode**
   ```json
   "groupPolicy": "mention-only"
   ```

3. **Use group allowlist**
   ```json
   "groupAllowlist": [
     "120363123456789012@g.us"  // Only this group
   ]
   ```

4. **Regularly review group membership**
   - Remove bot from inactive groups
   - Monitor for suspicious activity

### Getting Group JID

To allowlist a specific group, you need its JID:

```bash
# List all groups
moltbot message list-groups --channel whatsapp

# Output example:
# Family Chat: 120363123456789012@g.us
# Work Team: 120363987654321098@g.us
```

Add the JID to your config:

```json
"groupAllowlist": [
  "120363123456789012@g.us"
]
```

## Allowlist Management

### Adding to DM Allowlist

**By Phone Number:**

```json
"dmAllowlist": [
  "+1234567890",
  "+9876543210"
]
```

**Format:**
- Include country code
- Use E.164 format (+country code + number)
- No spaces or dashes

### Adding to Group Allowlist

**By Group JID:**

```json
"groupAllowlist": [
  "120363123456789012@g.us",
  "120363987654321098@g.us"
]
```

### Removing from Allowlist

Edit the config file and remove the entry, then restart:

```bash
nano ~/.moltbot/moltbot.json
# Remove the unwanted entry
docker compose restart moltbot-gateway
```

## Security Considerations

### Threat: Prompt Injection in Groups

**Attack:** Malicious group member crafts message to manipulate bot

**Mitigation:**
1. ✅ Use `mention-only` policy (attacker must @mention)
2. ✅ Use modern AI models with instruction hardening (Claude 3.5+)
3. ✅ Regularly review group membership
4. ✅ Use allowlisted groups only

### Threat: Spam DMs

**Attack:** Random users spam bot with messages

**Mitigation:**
1. ✅ Use `pairing` policy (users must explicitly pair)
2. ✅ Use `dmAllowlist` for known users only
3. ✅ Rate limiting (if supported)

### Threat: Social Engineering

**Attack:** Attacker tricks bot into performing actions

**Mitigation:**
1. ✅ Use `pairing` to verify user identity
2. ✅ Require @mention in groups (explicit intent)
3. ✅ Review bot activity logs
4. ✅ Use modern AI models resistant to social engineering

## Configuration Examples

### Example 1: Personal Use (Most Secure)

```json
{
  "channels": {
    "whatsapp": {
      "enabled": true,
      "dmPolicy": "pairing",
      "groupPolicy": "deny",
      "dmAllowlist": [],
      "groupAllowlist": [],
      "requireMentionInGroups": true
    }
  }
}
```

**Use Case:** Personal assistant, no groups
**Security:** Maximum (no group access at all)

### Example 2: Family/Friends (Balanced)

```json
{
  "channels": {
    "whatsapp": {
      "enabled": true,
      "dmPolicy": "allowlist",
      "groupPolicy": "mention-only",
      "dmAllowlist": [
        "+1234567890",  // Mom
        "+9876543210"   // Best friend
      ],
      "groupAllowlist": [
        "120363123456789012@g.us"  // Family group only
      ],
      "requireMentionInGroups": true
    }
  }
}
```

**Use Case:** Close contacts only
**Security:** High (explicit allowlists)

### Example 3: Small Team (Requires Careful Management)

```json
{
  "channels": {
    "whatsapp": {
      "enabled": true,
      "dmPolicy": "pairing",
      "groupPolicy": "allowlist",
      "dmAllowlist": [],
      "groupAllowlist": [
        "120363123456789012@g.us",  // Team group
        "120363987654321098@g.us"   // Project group
      ],
      "requireMentionInGroups": true
    }
  }
}
```

**Use Case:** Work team collaboration
**Security:** Medium (must trust all group members)

### Example 4: Public Bot (Not Recommended)

```json
{
  "channels": {
    "whatsapp": {
      "enabled": true,
      "dmPolicy": "open",
      "groupPolicy": "mention-only",
      "dmAllowlist": [],
      "groupAllowlist": [],
      "requireMentionInGroups": true
    }
  }
}
```

**Use Case:** Public service bot (not recommended for personal use)
**Security:** Low (anyone can DM)
**Requires:** Additional rate limiting, abuse detection, monitoring

⚠️ **Warning:** `dmPolicy: "open"` is dangerous. Only use if you understand the risks and have additional security controls.

## Verification

After configuring, verify with:

```bash
# Check configuration
cat ~/.moltbot/moltbot.json | jq '.channels.whatsapp'

# Run security audit
bash scripts/security-audit.sh

# Test pairing (if enabled)
# Send /pair from a test number
# Verify pairing workflow works
```

## Monitoring

Regularly review bot activity:

```bash
# Check logs
docker compose logs moltbot-gateway | tail -100

# Look for:
# - Unexpected group messages
# - Failed pairing attempts
# - Suspicious DMs
# - Rate limiting triggers
```

## Best Practices

✅ **DO:**
- Start with most restrictive settings (`pairing`, `mention-only`)
- Use allowlists for known contacts/groups
- Regularly review and prune allowlists
- Monitor logs for suspicious activity
- Use modern AI models with instruction hardening
- Document your configuration decisions

❌ **DON'T:**
- Use `dmPolicy: "open"` unless absolutely necessary
- Add bot to public groups
- Trust all group members equally
- Ignore suspicious activity
- Share bot credentials
- Use `groupPolicy: "open"` (responds to all messages)

## Troubleshooting

### Bot Not Responding in Group

1. Check `groupPolicy` - should be `"mention-only"` or `"allowlist"`
2. If `allowlist`, verify group JID is in `groupAllowlist`
3. Ensure you're @mentioning the bot
4. Check `requireMentionInGroups` is not contradicting policy

### Bot Not Accepting DMs

1. Check `dmPolicy`:
   - `"pairing"`: User needs to pair first with `/pair`
   - `"allowlist"`: User's number must be in `dmAllowlist`
2. Verify phone number format (E.164: +country code + number)
3. Check logs for pairing/auth errors

### Pairing Not Working

1. Verify pairing is enabled: `"dmPolicy": "pairing"`
2. Check pairing codes are being generated (logs)
3. Ensure user is sending pairing code to correct bot
4. Check pairing code expiration (typically 5-10 minutes)

## See Also

- `docs/security-configuration.md` - Overall security settings
- `docs/secrets-management.md` - API keys and secrets
- `v2_implementationplan` - Full security hardening plan
- `scripts/security-audit.sh` - Security verification

## Summary

**Recommended Safe Defaults:**
- `dmPolicy: "pairing"` - Require explicit pairing for DMs
- `groupPolicy: "mention-only"` - Only respond when @mentioned
- Empty allowlists initially
- Add contacts/groups explicitly as needed
- Monitor regularly for suspicious activity

This configuration provides strong protection against:
- Spam and abuse
- Prompt injection attacks
- Unauthorized access
- Social engineering

While still allowing legitimate use by trusted contacts and groups.
