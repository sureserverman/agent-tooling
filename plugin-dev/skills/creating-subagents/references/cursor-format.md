# Cursor subagent / rule format

Source of truth: `https://cursor.com/docs/subagents` and `https://cursor.com/docs` (rules). Facts below verified 2026-06-09 against Cursor 3.7. Verify with WebFetch if in doubt — Cursor's agent/rule distinction has changed over versions. For Cursor authoring depth beyond scaffolding, see the sibling `cursor-dev` plugin.

## Two mechanisms

1. **Rule files (`.mdc`)** in `.cursor/rules/` — auto-attach based on globs or `alwaysApply`. Used when behavior should kick in whenever the user is working in matching files.
2. **Agent files (`.md`)** in `~/.cursor/agents/` or `.cursor/agents/` — named subagents invoked via `@<name>`. Used when delegation is explicit.

Ship both. The rule auto-attaches in-editor when the user is in a relevant file; the agent gives them an explicit handle.

## File locations

| Scope   | Rule                      | Agent                          |
| :------ | :------------------------ | :----------------------------- |
| User    | n/a (rules are project)     | `~/.cursor/agents/<name>.md`     |
| Project | `.cursor/rules/<name>.mdc`  | `.cursor/agents/<name>.md`       |

Some testing-expert-style bundles also drop `<name>.mdc` at `.cursor/` root for historical compatibility.

### Compatibility reads (Cursor 3.7)

Cursor also reads agent files from other hosts' directories: `.claude/agents/`, `.codex/agents/`, `~/.claude/agents/`, and `~/.codex/agents/`. On a name conflict, the project-level file wins. Practical consequence for this bundle: a Claude Code agent file often needs **no porting at all** for Cursor — ship a dedicated `.cursor/agents/<name>.md` only when you want Cursor-specific frontmatter (`readonly`, `is_background`) or host affordances.

## `.mdc` rule frontmatter

```mdc
---
description: One-line blurb for what this rule does. Keep it tight — Cursor shows this inline.
globs:
  - "**/test/**"
  - "**/tests/**"
  - "**/*.test.*"
  - "**/*.spec.*"
alwaysApply: false
---

# <name> (Cursor build)

## Host affordances

- Editor-integrated: when the user is in a matching file this rule auto-attaches.
- Explicit chat invocation: `@<name>`.
- Prefer minimal diffs; don't rewrite files wholesale.

<!-- CORE -->
```

### Fields

| Field         | Notes                                                                                            |
| :------------ | :----------------------------------------------------------------------------------------------- |
| `description` | Shown in Cursor UI. Short.                                                                       |
| `globs`       | Array of file patterns that auto-attach the rule. Omit if always/never.                          |
| `alwaysApply` | Boolean. `true` = attach on every request. Usually `false` for domain-specific rules.            |

## `.md` agent frontmatter

```markdown
---
name: agent-name
description: Use proactively whenever <domain> is in play — <trigger phrases>. Stance sentence.
model: inherit
readonly: false
is_background: false
---

# <name> (Cursor subagent build)

## Host affordances

- Installed at `~/.cursor/agents/<name>.md` (global) or `.cursor/agents/<name>.md` (project).
- Cursor auto-delegates on description match; "use proactively" phrasing encourages routing.
- Authoring and review are sharpest in-editor (inline diff UX); execute & triage delegates to the terminal.
- Prefer minimal diffs.

<!-- CORE -->
```

### Fields

| Field           | Notes                                                                   |
| :-------------- | :---------------------------------------------------------------------- |
| `name`          | Optional — defaults to the filename stem. Lowercase + hyphens.           |
| `description`   | Routing signal. "Use proactively" phrasing nudges auto-delegation.       |
| `model`         | Inherits the session default if omitted, or a model ID like `composer-2`. |
| `readonly`      | Boolean. `true` = no file writes.                                        |
| `is_background` | Boolean. `true` = runs without blocking the chat.                        |

**No `tools` field.** Unlike Claude Code, Cursor agents cannot allowlist individual tools — the only tool restriction is the blanket `readonly` flag. Don't copy a `tools:` line from a Claude Code agent file; Cursor ignores it.

## Invocation & runtime

- Auto-dispatch based on description match (auto-delegation).
- Explicit: `/<name>` or natural language ("ask the <name> agent to …").
- Rules attach automatically when the user is in a file matching their globs.
- Agents run in **parallel**, each with its own context window.
- Built-in subagents: `Explore`, `Bash`, `Browser`.

## Host-affordance hints for the wrapper

- Cursor's strength is the inline diff UX — authoring and review feel natural.
- Terminal-side operations (test runs, builds) delegate to the `Bash` equivalent but return is slower than native.
- Multi-file sweeps work, but single-file minimal diffs are the flow the user expects.
- For rule files, use globs to scope attach (tests, CI config, package manifests).

## Common mistake

Shipping only the `.mdc` rule or only the `.md` agent. They serve different triggers — rules are passive (user is working in a file), agents are active (user explicitly `@<name>`s or Cursor auto-delegates on a request). Most bundles want both.
