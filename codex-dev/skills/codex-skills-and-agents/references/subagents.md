# Codex subagents and custom agents

Facts verified 2026-06-09 against [developers.openai.com/codex/subagents](https://developers.openai.com/codex/subagents) and the changelog, Codex CLI v0.139.0.

## Timeline

- **v0.115.0 (March 16, 2026)** — subagents generally available.
- **v0.137–v0.139** — multi-agent **v2 runtime** rolling out (performance/orchestration rework; same authoring format).

## Spawning model

**Codex spawns subagents only when explicitly asked.** There is no automatic delegation router: the user says "use the reviewer agent on this diff" (or a skill instructs it), and Codex spawns the named agent in its own thread. Inspect live threads with **`/agent`** in the TUI.

Design consequence: a custom agent's `description` is documentation for the human and the orchestrating model, not an auto-trigger surface like a skill description.

## Custom agent format — ONE TOML per agent

Locations:

| Scope | Path |
|---|---|
| Personal | `~/.codex/agents/<name>.toml` |
| Repo | `.codex/agents/<name>.toml` |

Each file defines exactly one agent. Do not merge multiple agents into one TOML.

### Required fields

| Field | Meaning |
|---|---|
| `name` | Agent identifier |
| `description` | What the agent is for (shown when picking/inspecting agents) |
| `developer_instructions` | The agent's system-level brief — its role, constraints, output contract |

Missing any of the three is an authoring error; `validate-codex-artifact.sh` errors on agent TOMLs without them.

### Optional fields (inherit from the parent session if omitted)

| Field | Notes |
|---|---|
| `model` | Pin a different model |
| `model_reasoning_effort` | `minimal` \| `low` \| `medium` \| `high` \| `xhigh` |
| `sandbox_mode` | `read-only` \| `workspace-write` \| `danger-full-access` — e.g. force reviewers read-only |
| `mcp_servers` | Restrict/extend which MCP servers the agent sees |
| `skills.config` | Per-agent skill enable/disable |

Inheritance is the default and usually right — pin only what must differ.

### Example

```toml
# .codex/agents/reviewer.toml
name = "reviewer"
description = "Read-only code reviewer: correctness, security, and style findings on a diff."
developer_instructions = """
You are a code reviewer. Examine the diff or files you are pointed at.
Report findings as a list: severity, file:line, what is wrong, why it matters.
Do not propose refactors beyond the diff. Do not modify files.
"""
model_reasoning_effort = "high"
sandbox_mode = "read-only"
```

## Runtime configuration — [agents] in config.toml

```toml
[agents]
max_threads = 6                  # default: at most 6 concurrent subagent threads
max_depth = 1                    # default: subagents cannot spawn sub-subagents
job_max_runtime_seconds = 600    # wall-clock cap per subagent job
```

| Key | Default | Meaning |
|---|---|---|
| `max_threads` | 6 | Concurrent subagent threads |
| `max_depth` | 1 | Nesting depth (1 = no recursive spawning) |
| `job_max_runtime_seconds` | — | Kill a subagent job after this many seconds |

Raise `max_depth` only deliberately — recursive agent trees multiply token spend fast.

## Design guidance

- **Read-only delegates** (reviewers, auditors, researchers): pin `sandbox_mode = "read-only"` so a delegated task can never write, regardless of the parent's mode.
- **developer_instructions is the contract** — state role, inputs, output format, and what the agent must NOT do. Vague instructions are the top cause of useless subagent output.
- **Keep agents narrow.** One job per agent; the explicit-spawn model means users pick agents by name, and a grab-bag agent is unpickable.
- **Skills + agents compose**: a skill body can instruct Codex to spawn a named agent for a sub-task — the skill provides the "when/how", the agent provides the isolated execution context.
- Porting from Claude Code: Claude's markdown agents (frontmatter + prose) become TOML — frontmatter `name`/`description` map 1:1, the markdown body becomes `developer_instructions` (use a TOML multi-line string), `tools:` restrictions approximate to `sandbox_mode` + `mcp_servers`.
