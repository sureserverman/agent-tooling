---
name: opencode-agents-and-commands
description: Use when defining or debugging OpenCode agents, subagents, or slash commands. Triggers on "OpenCode agent", "opencode subagent mode", ".opencode/agents", "OpenCode custom command", ".opencode/commands", "opencode.json agent config", "@mention agent", "opencode agent create", "primary vs subagent".
---

# opencode-agents-and-commands

OpenCode (opencode.ai terminal agent; canonical source **github.com/anomalyco/opencode**) has two prompt-level extension surfaces: **agents** — named personas with their own model, prompt, and permissions, cycled with Tab or invoked as subagents — and **commands** — `/name` prompt templates with argument substitution and shell injection. Both are markdown files with YAML frontmatter, with a JSON alternative in `opencode.json`.

All facts verified 2026-06-09 against opencode.ai/docs (agents, commands), OpenCode **v1.16.x** (June 2026).

## The number-one deprecation: `tools` → `permission`

**The per-agent `tools` boolean map (`tools: {bash: false}`) is deprecated.** Use `permission` with `"ask" | "allow" | "deny"` per key — keys: `read`, `edit`, `glob`, `grep`, `list`, `bash`, `task`, `webfetch`, `external_directory` — and **bash glob maps** for command-level granularity:

```yaml
permission:
  edit: deny
  webfetch: allow
  bash:
    "*": ask
    "git status *": allow
    "git log *": allow
```

`tools` still works for now, but the deterministic lane warns on it (`opencode-tools-deprecated`). Don't write new agents with it.

## Reference map

| When you need… | Read first |
|---|---|
| Agent file locations, the full frontmatter field set, modes (primary/subagent/all), overriding built-ins `build`/`plan`, the permission model, JSON-config form, modes→agents history | `references/opencode-agents.md` |
| Command file locations, frontmatter (`description`, `agent`, `model`, `subtask`), `$ARGUMENTS`/`$1..$3`, `` `!cmd` `` shell injection, `@file` inlining, JSON-config form | `references/opencode-commands.md` |

## Decision rules

### Agent or command?

| Signal | Surface |
|---|---|
| A standing *persona* — different model, prompt, permissions, temperature | **Agent** |
| A reusable *prompt* the user fires explicitly with arguments | **Command** |
| A command whose work should not pollute the main context | **Command with `subtask: true`** (runs as a subagent task) |
| Restricting what the main loop may do per-project | `permission` in `opencode.json`, no agent needed |

### Which agent mode?

- **`primary`** — Tab-cycles in the TUI; a top-level driver the user works *in*. Built-ins `build` (default, full permissions) and `plan` (restricted) are primaries; **redefining an agent with the same name overrides the built-in**.
- **`subagent`** — invoked by `@name` mention or dispatched automatically by a primary when its `description` matches the work. Lives in its own context window.
- **`all`** — usable both ways.

A subagent's `description` is its **trigger** — third person, specific, naming when to dispatch it. A vague description means it never fires automatically.

### File or JSON?

Markdown files (`.opencode/agents/<name>.md`, global `~/.config/opencode/agents/<name>.md`; **filename = agent name**) are the default — body is the system prompt, frontmatter the config. The `"agent"` key in `opencode.json` is equivalent and right when config must merge across the config layers (e.g. an org-managed restriction). `opencode agent create` scaffolds interactively — but verify it wrote into **`agents/`** (plural); issue #14410 had it scaffolding into singular `agent/`, which the loader ignored.

### Command anatomy in one glance

```markdown
---
description: Run the test suite and summarize failures
agent: build
subtask: true
---
Run tests for $ARGUMENTS.
Current branch: ! `git branch --show-current`
Follow the conventions in @docs/testing.md
```

`/test unit` substitutes `$ARGUMENTS` (or positionals `$1`..`$3`); `` `!cmd` `` executes **at parse time** and inlines stdout; `@path` inlines a file reference. Details and pitfalls in `opencode-commands.md`.

## Anti-patterns this skill catches

- New agents with a `tools:` boolean map — deprecated; use `permission` (`opencode-tools-deprecated`).
- Agent files in singular `.opencode/agent/` — silently ignored in known versions (issue #14410); plural `agents/` (`opencode-singular-dir`).
- Broken YAML frontmatter — the agent/command loads wrong or not at all (`opencode-frontmatter`).
- `description` missing on an agent — it's the required field; subagents without one can't be auto-dispatched.
- Calling agents "modes" and looking for a `mode:` config block — 0.x terminology; agents replaced modes (legacy `modes/` dir still acknowledged, don't author new ones).
- `` `!cmd` `` with side effects — it runs at parse time, *before* the user confirms anything; keep injections read-only (`git status`, not `git push`).
- A bash permission map without a `"*"` fallback — unmatched commands need an explicit default.

## Sources

- OpenCode, *Agents* — locations, frontmatter, modes, built-ins, permission model, `tools` deprecation ([opencode.ai/docs/agents](https://opencode.ai/docs/agents)). Verified 2026-06-09.
- OpenCode, *Commands* — locations, frontmatter, templates, shell injection, file references ([opencode.ai/docs/commands](https://opencode.ai/docs/commands)). Verified 2026-06-09.
- OpenCode repo — issue #14410 (`opencode agent create` singular-dir bug) ([github.com/anomalyco/opencode](https://github.com/anomalyco/opencode)). Verified 2026-06-09.

When upstream behavior changes, update the references — not this SKILL.md.
