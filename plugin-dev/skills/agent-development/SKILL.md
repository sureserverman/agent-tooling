---
name: agent-development
description: Use when authoring Claude Code subagents. Triggers on "agent frontmatter", "model pinning for agents", "agent triggering description", "haiku vs sonnet for agent".
---

# agent-development

Decision rules for writing Claude Code subagents: how to structure the file, what frontmatter fields do, how to pick a model and tool set, and how to write a body that produces structured output.

> **Determinism boundary.** `name`↔filename, `model`/`color` enums, and frontmatter/system-prompt presence are owned by `bash "${CLAUDE_PLUGIN_ROOT}/scripts/validate-agent.sh" <agent.md>`. Note it deliberately does **not** require `<example>` blocks or "Use this agent when…" phrasing — those conflict with leak-safe, third-person descriptions. Run it first; bring judgment to routing quality, tool-set minimalism, and model tier. (Generate write-capable agents with the `agent-creator` subagent.)

## Reference map

| When you need… | Read first |
|---|---|
| Description patterns, `<example>` blocks, auto-dispatch vs explicit invoke | `references/triggering.md` |
| Model tier decision matrix, tool-set selection by use-case | `references/model-and-tools.md` |

## Anatomy

An agent is a Markdown file at `agents/<name>.md` inside a plugin. The YAML frontmatter declares the agent; the body is the agent's system prompt verbatim.

```
agents/
└── link-checker.md      ← filename = agent name (kebab-case)
```

### Frontmatter fields

Only `name` and `description` are required.

| Field | Notes |
|---|---|
| `name` | kebab-case; must match the filename (without `.md`) |
| `description` | Trigger-spec for the parent's auto-dispatch — same rules as skill descriptions |
| `model` | `haiku`, `sonnet`, `opus`, `fable`, `inherit`, or a full model ID. Default: `inherit` |
| `tools` | Array of tool names; defaults to every tool available. Always constrain. |
| `disallowedTools` | Subtractive — removes tools from the inherited pool |
| `permissionMode` | `default` \| `acceptEdits` \| `auto` \| `dontAsk` \| `bypassPermissions` \| `plan` — **ignored for plugin agents** |
| `maxTurns` | Hard cap on agent turns |
| `skills` | Skill names whose **full content** is preloaded at agent startup |
| `mcpServers` | Server name refs or inline definitions — **ignored for plugin agents** |
| `hooks` | Agent-scoped lifecycle hooks — **ignored for plugin agents** |
| `memory` | `user` \| `project` \| `local` — persistent memory dir (e.g. `~/.claude/agent-memory/<name>/`) for cross-session learning |
| `background` | `true` = always runs as a background task |
| `effort` | Effort override for the agent's model |
| `isolation` | `worktree` = runs in a temp git worktree off the default branch; auto-cleaned if unchanged |
| `color` | Badge color, 8 named: `red`, `blue`, `green`, `yellow`, `purple`, `orange`, `pink`, `cyan` |
| `initialPrompt` | Auto-submitted first turn when the agent runs as the main session (`claude --agent <name>`) |

> **Plugin-shipped agents: `hooks`, `mcpServers`, and `permissionMode` are
> IGNORED** (security restriction). Plugin agents support
> name/description/model/effort/maxTurns/tools/disallowedTools/skills/
> memory/background/isolation. Never ship a plugin agent whose correctness
> depends on the three ignored fields — it will validate, load, and then
> silently run without them.

### Locations and priority

Highest wins on ID collision:

1. Managed settings (org)
2. `--agents` CLI JSON
3. `.claude/agents/` (project)
4. `~/.claude/agents/` (user)
5. Plugin `agents/`

Directories are scanned recursively; subfolders inside a plugin namespace
the agent ID — `agents/review/security.md` in `my-plugin` becomes
`my-plugin:review:security`.

Minimal valid agent:

```yaml
---
name: link-checker
description: Use when asked to audit links in a project. Triggers on "check links", "find broken URLs", "link audit".
model: haiku
tools: [Read, Glob, Bash]
---

You are a link-audit specialist...
```

## Model pinning — pick the right tier

| Use-case | Model | Reason |
|---|---|---|
| Read-only audits, grep/probe, log triage, link-check, formatting passes | `haiku` | ~3x cheaper than sonnet; fast for token-light work |
| Code generation, content transformation, mock-server scaffolding, agent file generation | `sonnet` | Correct default for write-capable workers |
| Complex reasoning, architecture decisions, plan synthesis, multi-hour agentic work | `opus` | Expensive — use sparingly |
| Domain experts where parent tier already matches complexity | `inherit` | Use only when the parent is already calibrated for the work — `inherit` is contingent, not a default safe choice |

**Never omit `model` on a heavy write agent.** The default is `inherit`: without a pin the agent silently runs at the parent's tier; on an Opus or Fable parent, that's up to ~5x the cost of a sonnet pin (and ~15x a haiku pin) per invocation.

## Tool set — constrain by role

| Role | Tool set |
|---|---|
| Read-only auditor | `Read`, `Grep`, `Glob`, `Bash` (probe-only), `WebFetch` |
| Write worker | above + `Write`, `Edit` |
| Orchestrator | above + `Agent` (spawns sub-subagents — rarely needed) |

Always list `tools:` explicitly. The default (all tools) exposes Write, Edit, and Agent to agents that should never touch files or spawn children. When the inherited pool is mostly right, `disallowedTools` subtracts the few that aren't (e.g. keep everything but `Write`/`Edit`). For risky write workers, `isolation: worktree` confines edits to a throwaway git worktree — see `references/model-and-tools.md`.

## System prompt (body) design

Open with role: `You are a [role] specialist...`

Structure every body with these four elements:

1. **Scope** — what the agent does AND does not do. Be explicit about boundaries.
2. **Invariants** — read-only? Bounded to specific paths? No commits? State them as hard rules.
3. **Output contract** — findings list, patch, verdict, or structured JSON? Specify the exact shape.
4. **Edge cases** — what to return when there is nothing to report, or input is malformed.

Agents without an output contract drift: they narrate their own reasoning and return free-form prose that callers cannot reliably parse.

## Non-negotiable rules

1. **`name` must match the filename.** `agents/foo-bar.md` must have `name: foo-bar`. Mismatch causes the agent to appear twice in autocomplete or fail to load.
2. **Always specify `tools:`.** Open tool sets are a scope and security problem.
3. **Always pin `model:`.** Unpin agents silently inherit the parent's tier.
4. **Description is third-person, trigger-spec style.** First-person ("I review...") defeats auto-dispatch matching. See `references/triggering.md`.
5. **Body is a system prompt, not a user prompt.** Do not paste the user's request verbatim — write a role brief.
6. **One purpose per agent.** Agents that do too much become unpredictable. Split on the output contract boundary.

## Decision shortcuts

### Should this be an agent or inline skill content?

- **Agent** when: the task is isolated (bounded inputs/outputs), benefits from a different model tier, or needs a constrained tool set for security.
- **Inline skill** when: the guidance is a short rule set that the parent already applies correctly with no model-tier or tool-scope change.

### When to use `color:`

Set a color when the plugin ships multiple agents that users may confuse in the IDE badge list. Match color to role: `red` for destructive/risk-surfacing agents, `green` for read-only auditors, `blue` for generators, `yellow` for linters/advisors.

## Anti-patterns

- **Unpinned model on a write agent** — Inherits Opus in Opus sessions; expensive.
- **Wide-open `tools:`** — Allows write agents to be invoked without Write/Edit listed, or audit agents to silently receive Write permission they should not have.
- **First-person `description:`** — `"I check links..."` — breaks trigger matching.
- **Agent doing too much** — A single agent that reads, generates, tests, and commits is impossible to constrain or test; split it.
- **Body = user prompt verbatim** — System prompts define role and constraints; user prompts provide the specific task. Conflating them makes the agent context-insensitive.
- **`name` / filename mismatch** — The runtime uses the filename for dispatch routing; the `name` field is used for display and deduplication. Divergence causes subtle bugs.
- **Plugin agent depending on `hooks`, `mcpServers`, or `permissionMode`** — These fields are ignored for plugin-shipped agents (security restriction). The agent loads fine and silently runs without them.

## Related

- Skill for plugin layout: `plugin-structure` (this plugin)
- Skill for skill authoring: `skill-development` (this plugin)
- Community agent canon: https://github.com/wshobson/agents (184 agents)
- Sub-agent docs: https://code.claude.com/docs/en/sub-agents (verified 2026-06-09 against Claude Code v2.1.170)
