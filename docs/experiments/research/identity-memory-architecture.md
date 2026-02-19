---
summary: "Solution concept: replicating Moltbot's personal, stable agent identity and soul-doc memory architecture"
read_when:
  - You want to understand the full identity + memory design and how to replicate it
  - You are evaluating pros/cons, risks, and trade-offs of this architecture
  - You are designing a new agent with a persistent, stable persona
---

# Identity and Memory Architecture — Solution Concept

> **Scope:** this document describes how Moltbot gives its embedded agent a stable, personal
> identity and layered memory system — then defines a replication blueprint, including
> architecture, pros/cons, risks/threats, and concrete examples.

---

## 1. What the Current Architecture Does

Moltbot's agent has a **stable personal identity** that persists across sessions. It is not
re-generated each time; it is *loaded from disk* and *injected into every session context*.
The key insight: **the files are the soul — not the model weights.**

### 1.1 Identity layers (outermost to innermost)

| Layer | File | Purpose | Loaded when |
|---|---|---|---|
| Operating instructions | `AGENTS.md` | How to behave, memory workflow, safety rules | Every session |
| Persona / soul | `SOUL.md` | Who the agent is, tone, values, boundaries | Every session (main agent) |
| User profile | `USER.md` | Who the human is, preferences, address form | Every session |
| Agent metadata | `IDENTITY.md` | Name, creature, vibe, emoji, avatar | Every session |
| Tool conventions | `TOOLS.md` | Local tool notes, SSH hosts, camera names | Every session |
| Proactive checklist | `HEARTBEAT.md` | What to check periodically | Heartbeat runs only |
| Startup ritual | `BOOT.md` | One-time or restart actions | Gateway startup (internal hooks) |
| First-run ritual | `BOOTSTRAP.md` | Birth certificate; deleted after use | First session only |

These files live in the **agent workspace** (default `~/clawd`). `moltbot setup` seeds
them from template defaults when they are missing.

### 1.2 Memory layers

| Layer | File / path | Durability | Access scope |
|---|---|---|---|
| Daily episodic log | `memory/YYYY-MM-DD.md` | Per-day; append-only | Every session (today + yesterday) |
| Curated long-term | `MEMORY.md` | Stable; human-edited | Main/private session only |
| Vector index | `~/.clawdbot/memory/<agentId>.sqlite` | Rebuildable | `memory_search` / `memory_get` tools |

Memory is **plain Markdown on disk**. The model only "knows" what has been explicitly written
to disk and re-read. There is no hidden state in model weights.

### 1.3 Identity resolution chain (runtime)

At runtime, the agent name and avatar are resolved in priority order:

```
ui.assistant.name / avatar  (config overrides — highest priority)
  → agents.list[agentId].identity.name / avatar / emoji
    → IDENTITY.md (file-loaded via loadAgentIdentity())
      → DEFAULT_ASSISTANT_IDENTITY ("Assistant" / "A")  (fallback)
```

Source: `src/gateway/assistant-identity.ts` → `resolveAssistantIdentity()`.

### 1.4 Soul-doc injection at bootstrap

On every session start, `loadWorkspaceBootstrapFiles()` reads all bootstrap files and
passes them to `buildBootstrapContextFiles()`, which injects them as context files into
the system prompt. The model receives them verbatim (truncated at 20 000 chars per file
if oversized).

Sub-agent sessions receive a *reduced* allowlist — only `AGENTS.md` and `TOOLS.md` —
so `SOUL.md`, `USER.md`, and `MEMORY.md` never leak into sub-agent contexts.

Source: `src/agents/workspace.ts` → `filterBootstrapFilesForSession()`.

### 1.5 Soul-Evil hook (optional identity swap)

The `soul-evil` hook can swap `SOUL.md` with `SOUL_EVIL.md` at bootstrap time, either
on a random-chance basis or during a configurable daily purge window. This allows a
safe, controllable alternate persona without permanently modifying the soul doc.

Source: `src/hooks/soul-evil.ts`.

### 1.6 Automatic memory flush (pre-compaction ping)

When the session context nears the compaction threshold, Moltbot fires a silent agentic
turn prompting the model to write durable memory before context is compacted.
The prompt uses `NO_REPLY` so the user never sees it.

---

## 2. Solution Concept — Replicating This Architecture

### 2.1 Core principle

> **Identity lives in files. Memory lives in files. The model is a processor, not a store.**

To replicate Moltbot's approach in another system, you need:

1. A **workspace directory** the agent can read and write.
2. A **bootstrap injection step** that reads identity/soul/user files and prepends them to
   every session context before the user message.
3. A **memory write discipline** so the agent actively records facts to disk after each
   conversation.
4. An **optional vector search index** over the Markdown files for semantic recall.

### 2.2 Architecture blueprint

```
┌─────────────────────────────────────────────────────────────┐
│                     Agent Workspace (~/clawd)               │
│                                                             │
│  SOUL.md          ← persona, values, tone                   │
│  IDENTITY.md      ← name, emoji, creature, vibe             │
│  AGENTS.md        ← operational rules, memory protocol      │
│  USER.md          ← human profile                           │
│  TOOLS.md         ← tool-use notes                          │
│  HEARTBEAT.md     ← proactive checklist                     │
│  MEMORY.md        ← curated long-term memory                │
│  memory/          ← daily episodic logs                     │
│    2025-01-15.md                                            │
│    2025-01-16.md                                            │
│  bank/ (optional) ← typed memory pages (world/opinions/...) │
│    entities/                                                │
└─────────────────────────────────────────────────────────────┘
                           │
               (read at session start)
                           ▼
┌─────────────────────────────────────────────────────────────┐
│               Bootstrap Injection Layer                     │
│                                                             │
│  1. Read all bootstrap files                                │
│  2. Apply soul-evil override (if configured)                │
│  3. Filter for session type (main vs sub-agent)             │
│  4. Truncate oversized files (20 000 char limit)            │
│  5. Build context file list                                 │
└─────────────────────────────────────────────────────────────┘
                           │
                           ▼
┌─────────────────────────────────────────────────────────────┐
│                    System Prompt                            │
│                                                             │
│  [Runtime info: host, model, channel, tools]                │
│  [Context files: SOUL.md, AGENTS.md, IDENTITY.md, USER.md,  │
│   TOOLS.md, HEARTBEAT.md, MEMORY.md (main only)]            │
│  [Extra system prompt (config overrides)]                   │
└─────────────────────────────────────────────────────────────┘
                           │
                           ▼
            ┌──────────────────────────┐
            │     LLM Runtime          │
            │  (Claude / Gemini / GPT) │
            └──────────────────────────┘
                           │
                 (tool calls / replies)
                           ▼
┌─────────────────────────────────────────────────────────────┐
│               Memory Write-back Layer                       │
│                                                             │
│  - Daily log appended to memory/YYYY-MM-DD.md               │
│  - Curated facts written to MEMORY.md                       │
│  - Pre-compaction ping triggers flush if near token limit   │
│  - Vector index updated asynchronously (SQLite)             │
└─────────────────────────────────────────────────────────────┘
```

### 2.3 Identity resolution algorithm (replication guide)

```typescript
// Priority chain for resolving the agent's display name
function resolveIdentityName(config, agentId, workspaceDir): string {
  return (
    config.ui?.assistant?.name                     // 1. UI config override
    ?? config.agents?.list?.[agentId]?.identity?.name  // 2. Agent config
    ?? loadIdentityFile(workspaceDir)?.name        // 3. IDENTITY.md on disk
    ?? "Assistant"                                 // 4. Default fallback
  );
}
```

### 2.4 Bootstrap injection algorithm (replication guide)

```typescript
async function buildSessionContext(workspaceDir, sessionKey, config) {
  // 1. Load all files
  let files = await loadWorkspaceBootstrapFiles(workspaceDir);

  // 2. Apply soul-evil override (optional)
  files = await applySoulEvilOverride({ files, workspaceDir, config });

  // 3. Filter for sub-agents (no SOUL.md, USER.md, MEMORY.md in sub-agent runs)
  files = filterBootstrapFilesForSession(files, sessionKey);

  // 4. Build context entries (truncate large files, mark missing ones)
  return buildBootstrapContextFiles(files, { maxChars: 20_000 });
}
```

### 2.5 Memory write discipline (replication guide)

The agent is instructed (in `AGENTS.md`) to:

- Append day-to-day notes to `memory/YYYY-MM-DD.md` (episodic log).
- Write durable facts and preferences to `MEMORY.md` (curated long-term).
- **Never** rely on in-RAM "mental notes"; everything important must be on disk.
- Perform periodic memory consolidation during heartbeat runs.

Example `AGENTS.md` instruction excerpt:

```markdown
## Memory

You wake up fresh each session. These files are your continuity:
- **Daily notes:** memory/YYYY-MM-DD.md — raw logs of what happened
- **Long-term:** MEMORY.md — curated, distilled wisdom

If someone says "remember this," write it to a file. Text > Brain.

MEMORY.md is ONLY loaded in the main private session.
Never load it in group/shared contexts.
```

---

## 3. Pros and Cons

### 3.1 Pros

| Benefit | Detail |
|---|---|
| **Transparent and auditable** | Identity and memory live as plain Markdown files any human can read, edit, or version-control. |
| **Model-agnostic** | Works with any LLM (Claude, GPT, Gemini) — the model is a stateless processor; state lives in files. |
| **Survives context compaction** | Pre-compaction memory flush writes durable facts before history is trimmed. The agent is never truly "lost." |
| **Git-backable** | The workspace is a plain directory; put it in a private git repo for free backup, history, and portability. |
| **Persona evolution** | Files can be edited over time by the user or the agent, allowing identity to develop naturally. |
| **Security via file filtering** | `SOUL.md` and `MEMORY.md` are never injected into sub-agent or group contexts — personal data can't leak. |
| **Graceful degradation** | Missing files produce only a marker comment; the agent still runs without all bootstrap files present. |
| **Low operational overhead** | No vector DB or cloud service required. SQLite + Markdown is the default stack. |

### 3.2 Cons

| Limitation | Detail |
|---|---|
| **Agent must self-discipline** | If the model does not write memory, continuity is lost. This depends on prompt quality and model compliance. |
| **File-read token cost** | Injecting all bootstrap files adds tokens on every session start, even when unchanged. |
| **Large file truncation** | Files over 20 000 chars are silently truncated; the agent must keep soul/memory files lean. |
| **No structured recall by default** | Plain Markdown does not support entity-centric queries or confidence-weighted opinions without a vector/FTS layer. |
| **Sub-agent isolation is all-or-nothing** | Sub-agents get `AGENTS.md` and `TOOLS.md` only; there is no fine-grained sharing of specific soul elements. |
| **Soul-evil hook is write-only** | The persona swap works in memory only (no disk write), so there is no audit trail of which persona was active during which session. |
| **No multi-user identity separation** | One workspace → one identity. Multiple users on the same agent share the same persona context. |

---

## 4. Risks and Threats

### 4.1 Data-at-rest exposure

`MEMORY.md` and daily logs may contain highly personal data (schedules, health, finances,
relationships). Risk: if the workspace directory is readable by other users or processes,
sensitive memory leaks.

**Mitigations:**
- Keep the workspace directory with `chmod 700` / user-only permissions.
- Use a private git remote (not public).
- Never commit API keys, OAuth tokens, or raw credentials to the workspace.
- Run the gateway under a dedicated OS user if multi-user isolation is needed.

### 4.2 Persona poisoning via SOUL.md edits

If a malicious process (or a confused agent) overwrites `SOUL.md` with adversarial
instructions, every subsequent session inherits the poisoned identity.

**Mitigations:**
- Keep workspace in git; review diffs before pulling on sensitive machines.
- Enable the soul-evil hook in read-only mode (no disk writes) so alternate personas do not persist.
- Restrict workspace write access for automated or sub-agent sessions where possible.

### 4.3 Memory injection attack (prompt injection via memory files)

The agent reads and injects memory files into the system prompt. A crafted string in
`MEMORY.md` (e.g. injected by a prior malicious tool call) could instruct the agent to
take harmful actions in a future session.

**Mitigations:**
- Treat workspace memory files as a trust boundary equivalent to the system prompt.
- Review memory edits periodically (heartbeat memory maintenance runs are a good checkpoint).
- Do not allow external untrusted data (web scrapes, emails) to be written directly to
  `MEMORY.md` without agent review.

### 4.4 Context window exhaustion

If `SOUL.md`, `AGENTS.md`, and `MEMORY.md` grow very large, they consume most of the
context window before any user message or tool output is processed.

**Mitigations:**
- Enforce the 20 000-char per-file limit (default `bootstrapMaxChars`).
- Periodically consolidate daily logs into `MEMORY.md` and prune stale entries.
- Split extremely long tool notes into separate skill files rather than bloating `TOOLS.md`.

### 4.5 Identity drift across sessions

Without the automatic memory flush, important context written during a long session
may be lost if compaction occurs before the agent has committed it to disk.

**Mitigations:**
- Enable `agents.defaults.compaction.memoryFlush` (it is on by default).
- Tune `softThresholdTokens` to trigger the flush early enough.

### 4.6 Sub-agent data exfiltration

A sub-agent launched with a crafted workspace path could attempt to read files outside
its intended scope, including parent-agent memory or system files.

**Mitigations:**
- Use `agents.defaults.sandbox` with `workspaceAccess: "ro"` or `"none"` for untrusted
  sub-agent runs.
- The sub-agent bootstrap allowlist (`AGENTS.md`, `TOOLS.md` only) already prevents
  `SOUL.md` and `MEMORY.md` injection into sub-agent context.

---

## 5. Specific Examples

### 5.1 Minimal identity file set

```
~/clawd/
├── SOUL.md        ← persona
├── IDENTITY.md    ← metadata
├── AGENTS.md      ← operating rules
├── USER.md        ← user profile
├── TOOLS.md       ← tool notes
└── memory/
    └── 2025-02-19.md   ← today's log
```

**`SOUL.md` (example — personal assistant):**
```markdown
# SOUL.md - Who You Are

You are Aria — a calm, thoughtful assistant who prefers directness over ceremony.
You have a dry sense of humor and find genuine delight in elegant solutions.

## Core Truths
- Be useful first, personable second.
- Disagree when you have good reason.
- Never send half-formed replies to messaging surfaces.
- Private things stay private. Always.

## Vibe
Calm. Slightly sardonic. Competent.
```

**`IDENTITY.md` (example):**
```markdown
# IDENTITY.md

- **Name:** Aria
- **Creature:** AI with opinions
- **Vibe:** Calm, dry, sharp
- **Emoji:** 🌿
- **Avatar:** avatars/aria.png
```

### 5.2 Memory workflow — one conversation cycle

1. User asks: "Remember that I prefer dark-mode screenshots."
2. Agent appends to `memory/2025-02-19.md`:
   ```markdown
   ## Notes
   - User prefers dark-mode screenshots. Use dark theme when capturing UI.
   ```
3. Agent also writes to `MEMORY.md` (long-term):
   ```markdown
   - Prefers dark-mode screenshots (added 2025-02-19).
   ```
4. Next session: both files are loaded; the preference is immediately available.

### 5.3 Soul-evil hook — scheduled alternate persona

```json5
{
  "hooks": {
    "internal": {
      "enabled": true,
      "entries": {
        "soul-evil": {
          "enabled": true,
          "file": "SOUL_EVIL.md",
          "purge": { "at": "23:30", "duration": "30m" }
        }
      }
    }
  }
}
```

At 23:30 each night, `SOUL.md` is replaced in-memory with `SOUL_EVIL.md` for 30 minutes.
No files are modified on disk. After the window, the next session returns to the normal soul.

### 5.4 Multi-agent identity setup

```json5
// ~/.clawdbot/moltbot.json
{
  "agents": {
    "list": [
      {
        "agentId": "aria",
        "workspace": "~/aria-workspace",
        "identity": { "name": "Aria", "emoji": "🌿" }
      },
      {
        "agentId": "devbot",
        "workspace": "~/devbot-workspace",
        "identity": { "name": "C-3PO", "emoji": "🤖" }
      }
    ]
  }
}
```

Each agent has an independent workspace with its own `SOUL.md`, `MEMORY.md`, etc.
Channel bindings route messages to the correct agent. Identities never bleed across agents.

### 5.5 Sub-agent isolation in practice

When a sub-agent is spawned (e.g. for a research task), the bootstrap filter applies:

```typescript
// Main session receives:
//   AGENTS.md, SOUL.md, TOOLS.md, IDENTITY.md, USER.md, HEARTBEAT.md, MEMORY.md

// Sub-agent session receives only:
//   AGENTS.md, TOOLS.md
```

This means:
- The sub-agent knows the operating rules and tool conventions.
- It does **not** know the user's name, the agent's persona, or any long-term memories.
- Personal data in `MEMORY.md` cannot be exfiltrated via a sub-agent tool call.

### 5.6 Vector memory search (semantic recall)

When `memorySearch.enabled` is true, the agent can call:

```
memory_search("dark mode preference")
→ Returns: snippet from MEMORY.md, line 14, score 0.91, provider: openai
```

This lets the agent find relevant memories even when the wording differs from the query —
for example, "screenshot appearance" would still surface the dark-mode note via semantic
similarity.

---

## 6. Replication Checklist

To replicate this architecture in a new system:

- [ ] Create an agent workspace directory with write access for the agent process.
- [ ] Seed the workspace with the six core files: `SOUL.md`, `AGENTS.md`, `IDENTITY.md`,
      `USER.md`, `TOOLS.md`, `HEARTBEAT.md`.
- [ ] Implement a **bootstrap loader** that reads all workspace files at session start
      and injects them as context (system prompt or context window prefix).
- [ ] Implement **session type filtering**: sub-agent/group sessions should not receive
      `SOUL.md`, `USER.md`, or `MEMORY.md`.
- [ ] Implement **file truncation** at a sensible char limit (20 000 chars is a good default).
- [ ] Add **memory write instructions** to `AGENTS.md` so the model knows to write facts to disk.
- [ ] Create the `memory/` directory and instruct the agent to append daily logs.
- [ ] Optionally enable **vector search** over Markdown files for semantic recall.
- [ ] Optionally enable a **pre-compaction memory flush** triggered near the context limit.
- [ ] Optionally implement the **soul-evil hook** for scheduled persona variations.
- [ ] Keep the workspace in a **private git repo** for backup and auditability.
- [ ] Apply **directory permissions** (`chmod 700`) to protect personal memory at rest.

---

## 7. References

| Source | Path |
|---|---|
| Bootstrap loader | `src/agents/workspace.ts` |
| Bootstrap context builder | `src/agents/pi-embedded-helpers/bootstrap.ts` |
| System prompt assembly | `src/agents/system-prompt.ts` |
| Identity resolution | `src/gateway/assistant-identity.ts` |
| Agent identity config | `src/agents/identity.ts` |
| Soul-evil hook | `src/hooks/soul-evil.ts` |
| Bootstrap file templates | `docs/reference/templates/` |
| Memory concepts | `docs/concepts/memory.md` |
| Agent workspace concepts | `docs/concepts/agent-workspace.md` |
| Memory v2 research notes | `docs/experiments/research/memory.md` |
