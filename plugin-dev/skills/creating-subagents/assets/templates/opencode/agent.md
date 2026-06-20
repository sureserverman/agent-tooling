---
description: <One-paragraph routing blurb with trigger phrases and stance sentence.>
mode: subagent
model: anthropic/claude-sonnet-4-20250514
temperature: 0.1
permission:
  edit: deny
  bash:
    "*": ask
    "grep *": allow
    "git diff": allow
    "git log*": allow
  webfetch: deny
---

# <AGENT_NAME> (OpenCode build)

## Host affordances

- Installed at `.opencode/agents/<AGENT_NAME>.md` (project) or `~/.config/opencode/agents/<AGENT_NAME>.md` (global) — plural `agents/` dir; the singular `agent/` form is legacy and may be silently ignored.
- TUI-first with client/server architecture; sub-sessions are navigable via arrow keys.
- Use the `permission:` block for fine-grained control (the old `tools:` boolean map is deprecated).
- Temperature kept low for analysis; bump for generative work.

<!-- CORE -->
