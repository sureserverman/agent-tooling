---
name: <AGENT_NAME>
description: <One-paragraph routing blurb. Include trigger phrases the user types, domain keywords, and a stance sentence. Keep under ~400 chars.>
tools: Read, Grep, Glob, Bash
model: inherit
---

# <AGENT_NAME> (Claude Code build)

## Host affordances

- Use `TaskCreate` / `TaskUpdate` to track <multi-step work> — one task per <unit>.
- Issue parallel Read/Grep/Glob calls in a single message to amortize latency.
- For large audits, dispatch further subagents to keep the parent context clean.
- Use `WebFetch` only to refresh citations on demand — not on every session.

<!-- CORE -->
