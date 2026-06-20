---
name: <AGENT_NAME>
description: Use proactively whenever <domain> is in play — <trigger phrases>. Stance sentence.
model: inherit
readonly: false
is_background: false
---

# <AGENT_NAME> (Cursor subagent build)

## Host affordances

- Installed at `~/.cursor/agents/<AGENT_NAME>.md` (global) or `.cursor/agents/<AGENT_NAME>.md` (project).
- Cursor auto-delegates based on `description`; "use proactively" encourages routing.
- Authoring and review are sharpest in-editor (inline diff UX); execute / triage delegates to the terminal.
- Prefer minimal diffs; do not rewrite files wholesale.

<!-- CORE -->
