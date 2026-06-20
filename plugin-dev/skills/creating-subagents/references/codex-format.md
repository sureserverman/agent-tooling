# Codex CLI (OpenAI) subagent format

Source of truth: `https://developers.openai.com/codex/subagents` and `https://developers.openai.com/codex/guides/agents-md`. Facts below verified 2026-06-09 against Codex v0.139. Verify with WebFetch before writing if unsure — schema evolving. For Codex authoring depth beyond scaffolding, see the sibling `codex-dev` plugin.

Subagents are GA since v0.115.0 (Mar 2026); the multi-agent v2 runtime landed across v0.137–v0.139 (Jun 2026). One TOML file per agent.

## Three mechanisms, one repo

Codex has three ways to inject agent behavior. Pick based on use case:

1. **`AGENTS.md`** — a markdown file at repo root (or `~/.codex/AGENTS.md` globally). Auto-attached when the relevant context is in play. Good for single-agent repos or "always-on" operating instructions.
2. **`agents/<name>.toml`** — a proper subagent definition that Codex can spawn by name. Good for multi-agent repos and explicit delegation. This is what `testing-expert` uses.
3. **`prompts/<name>.md`** — a slash-command prompt available as `/<name>`. Good for explicit user-initiated invocations that aren't "full" subagents.

The full bundle ships all three so the user can pick their workflow. If unsure, ship at minimum `agents/<name>.toml` — it is the richest mechanism.

## File locations

| Scope   | `AGENTS.md`         | `agents/<name>.toml`             | `prompts/<name>.md`           |
| :------ | :------------------ | :------------------------------- | :---------------------------- |
| User    | `~/.codex/AGENTS.md`  | `~/.codex/agents/<name>.toml`      | `~/.codex/prompts/<name>.md`    |
| Project | `./AGENTS.md`         | `.codex/agents/<name>.toml`        | `.codex/prompts/<name>.md`      |

Filename stem should match `name`.

## `agents/<name>.toml` schema

```toml
name = "agent-name"
description = "One-paragraph routing blurb. When to spawn. Trigger phrases. Stance."
sandbox_mode = "workspace-write"
nickname_candidates = ["Triager", "Reviewer"]

# Optional (inherit from the parent session if omitted):
# model = "gpt-5.2-codex"
# model_reasoning_effort = "medium"
# [[mcp_servers]]
# name = "..."
# [skills.config]
# ...

developer_instructions = """
<!-- CORE -->
"""
```

### Fields

| Field                   | Required | Notes                                                                                                                 |
| :---------------------- | :------- | :-------------------------------------------------------------------------------------------------------------------- |
| `name`                  | yes      | The identifier used when spawning. Matches filename by convention but `name` is source of truth.                        |
| `description`           | yes      | Human-facing guidance; also routing signal.                                                                            |
| `developer_instructions`| yes      | The system prompt. Triple-quoted string. This is where `<!-- CORE -->` lives.                                          |
| `model`                 | no       | Model ID. Inherits from the parent session if omitted.                                                                |
| `model_reasoning_effort`| no       | Reasoning intensity. Inherits from the parent session if omitted.                                                     |
| `sandbox_mode`          | no       | `read-only`, `workspace-write`, or others. Inherits from the parent session if omitted.                               |
| `nickname_candidates`   | no       | Array of display names Codex cycles through for concurrent spawns.                                                   |
| `mcp_servers`           | no       | Array of MCP server configs scoped to this agent. Inherits from the parent session if omitted.                         |
| `skills.config`         | no       | Skills configuration. Inherits from the parent session if omitted.                                                    |

All optional fields inherit from the parent session when omitted — only set them when the subagent should diverge.

### Sandbox modes

Pick the tightest that still lets the agent do its job:

- `read-only` — no file writes, no shell mutation. Researchers and reviewers.
- `workspace-write` — writes scoped to the current workspace. Most feature/test authors.
- (Wider modes exist; check docs before using.)

## `AGENTS.md` shape

```markdown
# <agent-name> (Codex build)

When <domain triggers> are in play — <list of triggers> — operate as the **<agent-name>** agent defined below.

## Host affordances

- Shell-first: drive via `bash -lc`.
- Author via apply-patch diffs scoped to one file at a time.
- Announce protocol transitions in prose (no subagent affordance in Codex direct mode).
- Keep triage output literal — Codex's strength is exec discipline.

<!-- CORE -->
```

`AGENTS.md` is free-form markdown; Codex treats it as attached context.

## `prompts/<name>.md` shape

```markdown
# /<name> prompt

Explicit invocation for a <name> session. Use when you want a focused <domain> session that does not auto-attach via `AGENTS.md`.

## Host affordances

- Shell-first execution; announce protocol transitions in prose.
- One-file apply-patch diffs for authoring.

<!-- CORE -->
```

## Invocation

- Spawn a subagent: Codex spawns subagents **only when explicitly asked** — it does not auto-delegate the way Claude Code or Cursor do. Tell the user to ask by name ("spawn <name> to …").
- `/agent` inspects running subagent threads.
- Slash-prompt: `/<name>` runs the prompt file as a one-shot.
- `AGENTS.md`: implicit, attached when relevant.

## Global `[agents]` settings

In `~/.codex/config.toml`:

```toml
[agents]
max_threads = 6              # default 6
max_depth = 1                # default 1
job_max_runtime_seconds = 600
```

Bundle shouldn't touch this — it's user-global.

## Host-affordance hints for the wrapper

- Codex is shell-first. Favor pipelines over orchestration.
- `apply_patch` diffs are the native edit primitive — scope to one file per patch.
- No subagent-spawning affordance from inside a subagent. Announce protocol transitions in prose instead.
- Sandbox honors `sandbox_mode` strictly — don't ask the agent to do things the sandbox blocks.
