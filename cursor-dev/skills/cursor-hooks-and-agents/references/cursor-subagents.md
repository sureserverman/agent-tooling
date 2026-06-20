# Cursor subagents — discovery, frontmatter, built-ins (verified 2026-06-09, Cursor 3.7)

Subagents are markdown-defined agents the main agent can delegate to. Each runs
in **its own clean context window**, and independent subagents run **in
parallel**. Use them for isolation (don't pollute the main context), parallel
fan-out, or a restricted posture (`readonly`).

## Discovery paths

| Scope | Native path | Compat reads |
|---|---|---|
| Project | `.cursor/agents/` | `.claude/agents/`, `.codex/agents/` |
| User | `~/.cursor/agents/` | `~/.claude/agents/`, `~/.codex/agents/` |

- One agent per markdown file; the filename (minus `.md`) is the default name.
- **Project wins** over user/home on a name collision.
- The compat reads mean an existing Claude Code or Codex agents directory works
  without copying — but Cursor still applies *its* frontmatter semantics (see
  below), so Claude-Code-only fields are dead weight.

## Frontmatter

```markdown
---
name: db-migration-reviewer
description: Reviews schema migrations for destructive operations. Use proactively after any file edit under migrations/.
model: inherit
readonly: true
is_background: false
---

You are a database migration reviewer. For each migration file…
```

| Field | Type | Meaning |
|---|---|---|
| `name` | string, optional | Defaults to the filename. |
| `description` | string | **The routing signal** — the main agent picks subagents by description. Phrasing like "use proactively" nudges auto-delegation. |
| `model` | string | Inherit the session default, or pin a model id. |
| `readonly` | bool | Restricts the subagent to non-mutating operations. |
| `is_background` | bool | Run in the background; the main agent continues without waiting. |

**There is no `tools` field.** Unlike Claude Code, you cannot whitelist tools
per agent — `readonly: true` is the only restriction lever. A `tools:` list in
the frontmatter is silently meaningless.

## Built-in subagents

Cursor ships three; don't duplicate them:

| Built-in | Covers |
|---|---|
| `Explore` | Codebase exploration / search fan-out |
| `Bash` | Shell execution |
| `Browser` | Web browsing |

## Behavior notes

- Delegation is model-driven: the main agent matches the task against
  subagent descriptions. Weak descriptions → never invoked.
- Each invocation starts with a clean context; the subagent reports back a
  result, not its transcript. Don't assume it sees the main conversation.
- Parallelism is free: independent subagent calls run concurrently.
- Hook events `subagentStart` / `subagentStop` fire around runs; `subagentStop`
  honors `loop_limit` (see `cursor-hooks.md`).

## Differences from Claude Code agents (do not port blindly)

1. **No `tools` field** — remove it; use `readonly: true` if you need restriction.
2. Extra fields Claude Code lacks: `readonly`, `is_background`.
3. Discovery also reads `.claude/agents/` and `.codex/agents/` (project and
   home), so one source dir can serve multiple tools — author to the
   intersection of semantics.

Source: [cursor.com/docs/subagents](https://cursor.com/docs/subagents).
Verified 2026-06-09.
