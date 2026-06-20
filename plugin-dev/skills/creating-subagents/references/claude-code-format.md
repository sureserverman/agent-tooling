# Claude Code subagent format

Source of truth: `https://code.claude.com/docs/en/sub-agents` (was `docs.claude.com/en/docs/claude-code/sub-agents`). Facts below verified 2026-06-09 against Claude Code v2.1.170. Verify with WebFetch if something looks off — the schema has evolved.

## File location

| Scope               | Path                       | Notes                                     |
| :------------------ | :------------------------- | :---------------------------------------- |
| User (all projects) | `~/.claude/agents/<n>.md`  | Recommended default for portable agents   |
| Project             | `.claude/agents/<n>.md`    | Checked into repo; project-only           |
| Plugin              | `<plugin>/agents/<n>.md`   | Distributed via plugin; some fields blocked |

Filename stem should match `name:` frontmatter. Lowercase letters and hyphens only.

## Frontmatter

Only `name` and `description` are required. Everything else is optional.

```markdown
---
name: agent-name
description: One paragraph. What the agent does + when to delegate + (optional) stance.
tools: Read, Grep, Glob, Bash
model: inherit
---

<system prompt in markdown>
```

### Fields

| Field             | Required | Notes                                                                                              |
| :---------------- | :------- | :------------------------------------------------------------------------------------------------- |
| `name`            | yes      | Lowercase-hyphen identifier. Unique.                                                                |
| `description`     | yes      | The routing mechanism. Include trigger phrases, domain, and stance. Keep under ~400 chars.          |
| `tools`           | no       | Allowlist, comma-separated. Omit to inherit all. Common: `Read, Grep, Glob, Bash, Edit, Write, WebFetch, TaskCreate, TaskUpdate`. |
| `disallowedTools` | no       | Denylist. Applied before `tools`. Useful for "inherit everything except writes".                    |
| `model`           | no       | `sonnet` / `opus` / `haiku` / full ID (`claude-opus-4-7`) / `inherit`. Defaults to `inherit`.       |
| `permissionMode`  | no       | `default` / `acceptEdits` / `auto` / `dontAsk` / `bypassPermissions` / `plan`. Parent may override. |
| `maxTurns`        | no       | Hard stop on agentic turns.                                                                         |
| `skills`          | no       | List of skill names to preload into the subagent's context.                                          |
| `mcpServers`      | no       | Per-subagent MCP servers. String ref reuses parent conn; inline object defines fresh.               |
| `hooks`           | no       | Subagent-scoped lifecycle hooks. **Not supported in plugin agents.**                                |
| `memory`          | no       | `user` / `project` / `local` — persistent directory the agent can write to across sessions.         |
| `background`      | no       | Boolean. Always run this subagent as a background task.                                             |
| `effort`          | no       | `low` / `medium` / `high` / `xhigh` / `max`. Depends on model.                                      |
| `isolation`       | no       | `worktree` — subagent runs in a throwaway git worktree.                                              |
| `color`           | no       | `red` / `blue` / `green` / `yellow` / `purple` / `orange` / `pink` / `cyan`.                        |
| `initialPrompt`   | no       | Auto-submitted first user turn when running via `--agent`.                                           |

Plugin-shipped agents **ignore** `hooks`, `mcpServers`, and `permissionMode` — those fields are stripped on load. If the agent needs them, install to `~/.claude/agents/` or `.claude/agents/` instead of distributing via a plugin.

## Writing the description

Claude routes tasks to subagents based on description match. A good description has:

- A stance sentence: "Opinionated: <position>".
- Trigger phrases users actually type: `"run tests"`, `"flaky test"`, `"coverage gap"`.
- Domain keywords so routing is sharp vs. adjacent agents.
- No self-reference like "you are an expert in…". That belongs in the body.

Example:
```yaml
description: Use this agent to run, debug, and triage tests; to write new tests; to audit coverage; to review existing tests for smells; or to explain testing methodology. Trigger phrases include "run tests", "test failures", "flaky test", "coverage gap", "write tests for", "review these tests", "why TDD", "mutation testing". Opinionated: test pyramid, mutation-score-over-line-coverage, OWASP baseline, no snapshot theater.
```

## Body conventions

The markdown body IS the system prompt. No headers required, but conventional sections:

1. **Host affordances** — what Claude Code gives this agent that other hosts don't (e.g. `TaskCreate`/`TaskUpdate` for per-item tracking, parallel tool calls in a single message, subagent dispatch for audits). Keep this 3–6 bullets.
2. **Core content** (identity, operating model, rules, schemas, safety) — this is the `<!-- CORE -->` block from `_core.md`.

The body receives no Claude Code system prompt — only the environment (cwd, platform). Be explicit about what the agent should do.

## Working directory

Subagents start in the main conversation's cwd. `cd` does not persist between Bash calls inside the subagent. For isolated work, set `isolation: worktree`.

## Tool restriction — the usual shapes

Read-only researcher:
```yaml
tools: Read, Grep, Glob, Bash, WebFetch
```

Everything except writes:
```yaml
disallowedTools: Write, Edit
```

Full restriction to a fixed tool set:
```yaml
tools: Read, Grep, Glob
# no Bash, no Edit, no Write, no MCP
```

## Invocation

- Auto-delegation: Claude decides based on description when the user's request matches.
- Explicit: `Use the <name> agent to <task>`.
- Programmatic: `--agents '{"<name>": {...}}'` at CLI launch.
- The `/agents` command opens an interactive manager.

## Host-affordance hints for the wrapper

- Use `TaskCreate` / `TaskUpdate` for multi-step workflows — Claude Code persists these to the session UI.
- Issue parallel Read/Grep/Glob calls in a single message to amortize latency.
- For large audits, dispatch further subagents to protect the parent context.
- `WebFetch` for on-demand doc refresh only, not on every session.
