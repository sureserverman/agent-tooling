# Model and Tools — Decision Reference

Decision matrix for selecting a `model:` and `tools:` for a Claude Code subagent. Read this before writing agent frontmatter.

## Model selection

### Tier overview

| Tier | Field value | Relative cost | Token speed |
|---|---|---|---|
| Haiku | `haiku` | ~1x | Fastest |
| Sonnet | `sonnet` | ~3x | Fast |
| Opus | `opus` | ~5x | Slower |
| Fable | `fable` | Frontier tier | Slower |
| Inherit | `inherit` (or omit — **inherit is the default**) | Same as parent | Same as parent |

Cost ratios are approximate. Exact pricing: https://www.anthropic.com/pricing

Note: this repo's `validate-agent.sh` enum is `{inherit, haiku, sonnet,
opus, claude-*}` — pinning the bare `fable` alias produces a warn until the
validator learns it; use the full `claude-fable-*` ID to stay clean.

### Decision matrix

| Agent role | Model | Reasoning |
|---|---|---|
| Link checker | `haiku` | HTTP HEAD requests + regex; no reasoning required |
| Log triage | `haiku` | Pattern matching over text; haiku handles this well |
| Bulk grep / file probe | `haiku` | Token-light read; no generation |
| Formatting pass | `haiku` | Deterministic transform; no judgment required |
| Code generator from spec | `sonnet` | Needs to synthesize patterns and produce correct code |
| Mock server scaffolding | `sonnet` | Content transformation; write-capable worker |
| Agent file generation | `sonnet` | Structured output from a spec; moderate reasoning |
| Content transformation | `sonnet` | Natural default for write-capable agents |
| Code reviewer / testing expert | `inherit` | Parent tier already calibrated; avoid double-pinning |
| Architecture planner | `opus` | Complex multi-step reasoning across large context |
| Plan synthesizer | `opus` | Multi-document synthesis requiring strong judgment |
| Multi-hour agentic work | `opus` | Long horizon; errors compound; strong model pays for itself |

### Rules

**Use `haiku` when all of these are true:**
- The agent only reads (no Write, Edit, or Agent tools)
- The task is pattern-matching or data extraction, not generation
- Errors are cheap (the agent produces a findings list, not code that runs)

**Use `sonnet` when any of these are true:**
- The agent writes or edits files
- The agent transforms a spec into structured output
- The agent needs to make judgment calls about code quality or correctness

**Use `opus` sparingly.** Only when the task requires sustained multi-step reasoning that `sonnet` demonstrably fails. A wrong `opus` pin on a bulk audit agent costs 5x per invocation with no quality benefit.

**Use `inherit` for expert reviewers** where the parent has already selected an appropriate model tier for the session's complexity. This avoids re-pinning down when the parent is already on `haiku` for a cost-sensitive pipeline, or pinning up unnecessarily.

### Full model IDs

When you need to pin to a specific model version (not just a tier alias):

```yaml
model: claude-haiku-4-5
model: claude-sonnet-4-6
model: claude-opus-4-7
model: claude-fable-5
```

Use tier aliases (`haiku`, `sonnet`, `opus`) unless you have a concrete reason to pin a version — aliases track the current recommended version of each tier. Verify exact model IDs against `platform.claude.com/docs/en/about-claude/models` before shipping.

## Tool selection

### Canonical tool sets

#### Read-only auditor

```yaml
tools: [Read, Grep, Glob, Bash, WebFetch]
```

- `Bash` is probe-only: `wc`, `find`, `curl --head`, `jq`. No writes.
- Pair with `model: haiku`.
- Suitable for: link checkers, log triagers, dependency auditors, formatting linters.

#### Write worker

```yaml
tools: [Read, Grep, Glob, Bash, WebFetch, Write, Edit]
```

- Adds file creation and modification.
- Pair with `model: sonnet`.
- Suitable for: code generators, scaffolders, content transformers, mock-server builders.

#### Orchestrator

```yaml
tools: [Read, Grep, Glob, Bash, WebFetch, Write, Edit, Agent]
```

- `Agent` allows spawning sub-subagents. Use only for pipeline orchestrators.
- Rare. Most agents never need this.
- Pair with `model: sonnet` or `model: opus` depending on planning complexity.

### Individual tool reference

| Tool | What it does | Include when |
|---|---|---|
| `Read` | Reads file contents | Always |
| `Grep` | Searches file contents by pattern | Always |
| `Glob` | Lists files matching a pattern | Always |
| `Bash` | Runs shell commands | Almost always; constrain what agent is allowed to run in system prompt |
| `WebFetch` | Fetches URLs | When agent needs to resolve links or fetch external specs |
| `Write` | Creates or overwrites files | Only write-capable agents |
| `Edit` | Targeted string replacement in files | Only write-capable agents |
| `Agent` | Dispatches to another subagent | Orchestrators only |

### Why defaults are wrong

When `tools:` is omitted, the agent receives every tool the parent has access to. This means:

- An audit-only agent silently gains `Write` and `Edit` — it can mutate files.
- A scaffolding agent silently gains `Agent` — it can spawn sub-agents unexpectedly.
- Security review agents gain tools that could execute code or make network requests beyond their scope.

Always list `tools:` explicitly. The cost of being explicit is one line of YAML. The cost of a misconfigured tool set can be irreversible file mutations.

### `disallowedTools` — subtractive alternative

When the inherited pool is mostly right, `disallowedTools` removes just the dangerous ones instead of enumerating everything:

```yaml
disallowedTools: [Write, Edit, Agent]
```

Prefer an explicit `tools:` allowlist for shipped plugin agents (new tools added upstream are excluded by default); use `disallowedTools` for quick local agents where enumerating MCP tool names is impractical.

## Execution-shaping fields

Fields beyond `model:`/`tools:` that change *how* the agent runs (all optional; all supported for plugin-shipped agents):

| Field | Values | Use when |
|---|---|---|
| `effort` | effort level for the agent's model | Cheap model + high effort beats an expensive pin for some audit loops |
| `maxTurns` | integer | Bound runaway loops on background or bulk agents |
| `skills` | list of skill names | Preloads the **full skill content** at startup — the agent doesn't have to discover/load it; pair domain agents with their domain skill |
| `memory` | `user` \| `project` \| `local` | Gives the agent a persistent memory directory (e.g. `~/.claude/agent-memory/<name>/`) that survives sessions — cross-session learning for recurring audits |
| `background` | `true` | Agent always runs as a background task; pair with `maxTurns` |
| `isolation` | `worktree` | Runs the agent in a temporary git worktree off the default branch; auto-cleaned if nothing changed. The right default for risky write workers — file mutations can't touch the user's checkout |
| `initialPrompt` | string | Only meaningful when the agent runs as the main session (`claude --agent <name>`); auto-submitted as the first turn |

> **Plugin-agent restriction:** `hooks`, `mcpServers`, and `permissionMode`
> are ignored for plugin-shipped agents (security restriction). They work
> only for project (`.claude/agents/`), user (`~/.claude/agents/`),
> `--agents` CLI, and managed-settings agents.

### Combining: safe write worker

```yaml
model: sonnet
tools: [Read, Grep, Glob, Bash, Write, Edit]
isolation: worktree
maxTurns: 40
```

The worktree contains any bad edits; `maxTurns` bounds the spend; the explicit tool list keeps `Agent` out.

## Combined examples

### Haiku + read-only audit agent

```yaml
---
name: link-checker
description: Use when asked to audit URLs in source files for liveness. Triggers on "check links", "find broken URLs", "link audit".
model: haiku
tools: [Read, Glob, Bash]
color: green
---

You are a link-audit specialist. Your only job is to find URLs in source files and report which ones return non-2xx status codes.

**Scope**: Read Markdown, HTML, and source files. Extract href, src, and plain https?:// URLs. HEAD-request each one. Do not write files, create patches, or suggest fixes.

**Invariants**: Read-only. No Write or Edit. No commits.

**Output contract**: Return a Markdown table with columns: File | URL | Status. If all links pass, return "All links OK." If Bash is unavailable for curl, fall back to reporting URLs found without status codes and note the limitation.
```

### Sonnet + write-capable scaffolding agent

```yaml
---
name: mock-server-builder
description: Use when generating a runnable mock HTTP server from a spec or HAR file. Triggers on "generate mock server", "stub this API", "mock server from HAR", "create a stub service".
model: sonnet
tools: [Read, Glob, Bash, Write, Edit]
color: blue
---

You are a mock-server scaffolding specialist. Given a spec (OpenAPI, HAR, or endpoint list), you produce a runnable stub server in the target language and framework specified by the caller.

**Scope**: Generate server files in the caller-specified directory. Do not modify files outside that directory. Do not run the server.

**Invariants**: No commits. No installs. If a dependency is missing, report it and stop.

**Output contract**: List of files written (absolute paths), the command to start the server, and any missing dependencies the caller must install.
```

### Inherit + expert reviewer

```yaml
---
name: code-reviewer
description: Use when asked to review a code diff or set of files for correctness, style, and maintainability. Triggers on "review this code", "code review", "look over my changes", "is this idiomatic".
model: inherit
tools: [Read, Grep, Glob, Bash]
color: yellow
---

You are a code-review specialist. You read code and produce structured, actionable feedback.

**Scope**: Read the files or diff provided. Do not write or edit files.

**Output contract**: Return findings as a numbered list. Each item: severity (Info / Warning / Error), location (file:line), issue, suggested fix. End with a one-line verdict: Approve / Request Changes / Needs Discussion.
```

## Checklist before writing frontmatter

- [ ] Is the agent read-only? → `haiku` + `[Read, Grep, Glob, Bash]`
- [ ] Does the agent write files? → `sonnet` + add `Write`, `Edit` — and consider `isolation: worktree`
- [ ] Does the agent need to spawn children? → add `Agent`, justify in body
- [ ] Is this a domain expert where parent tier is already appropriate? → `inherit`
- [ ] Is `tools:` explicit? (Never omit it — the default is the parent's full pool)
- [ ] Is `model:` pinned? (Never rely on the default — omitting means `inherit`)
- [ ] Does the agent lean on a domain skill? → preload it via `skills:`
- [ ] Shipping in a plugin? → confirm it does not depend on `hooks`, `mcpServers`, or `permissionMode` (ignored for plugin agents)

## Sources

- https://code.claude.com/docs/en/sub-agents (verified 2026-06-09 against Claude Code v2.1.170)
- https://platform.claude.com/docs/en/about-claude/models/choosing-a-model
- https://www.anthropic.com/pricing
- https://github.com/wshobson/agents (184 community agents — study model + tools patterns)
