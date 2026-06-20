# OpenCode commands (verified 2026-06-09, OpenCode v1.16)

Commands are `/name` prompt templates typed in the TUI.

## Locations

| Scope | Path |
|---|---|
| Project | `.opencode/commands/<name>.md` |
| Global | `~/.config/opencode/commands/<name>.md` |
| JSON | `"command"` key in `opencode.json` (with a `template` field) |

- **Filename = command name**: `commands/test.md` → `/test`.
- Plural `commands/` is canonical; singular `command/` is legacy with
  silent-ignore history (`opencode-singular-dir`).
- Markdown body = the prompt template; frontmatter = config.

## Frontmatter

| Field | Meaning |
|---|---|
| `description` | shown in the TUI command list |
| `agent` | which agent runs the prompt (e.g. `build`, `plan`, or a custom one) |
| `model` | `provider/model-id` override for this command |
| `subtask` | `true` → force the command to run as a **subagent task**: its work happens in a separate context window and only the result returns — use for noisy/long operations that would pollute the main session |

## Template substitution

Three mechanisms, all resolved when the command is invoked:

### 1. Arguments

- `$ARGUMENTS` — everything typed after the command name, verbatim.
- `$1`, `$2`, `$3` — positional words (whitespace-split). Positionals beyond
  `$3` are not supported.

```markdown
---
description: Create a component with tests
---
Create a $1 component named $2 under src/components/, with tests.
```

`/component button IconButton` → `$1`=`button`, `$2`=`IconButton`.

### 2. Shell injection — `` !`cmd` ``

`` !`command` `` runs the command **at parse time** (when the user invokes
the slash command, before the model sees anything) and inlines stdout:

```markdown
---
description: Summarize current changes
agent: plan
---
Summarize these changes:
!`git diff --stat`
!`git log --oneline -5`
```

Pitfalls:

- Runs **before any permission prompt** — never put side-effecting commands
  (`git push`, `rm`, network writes) in an injection. Read-only only.
- Output is inlined raw — a huge diff blows up the prompt; prefer `--stat`,
  `head`, etc.

### 3. File references — `@path`

`@docs/testing.md` inlines a reference to that file so the agent reads it as
part of the command. Paths are project-relative.

## JSON form

```json
{
  "$schema": "https://opencode.ai/config.json",
  "command": {
    "test": {
      "description": "Run the test suite and summarize failures",
      "agent": "build",
      "subtask": true,
      "template": "Run the test suite for $ARGUMENTS and summarize failures."
    }
  }
}
```

Equivalent to the file form; `template` replaces the markdown body. Merges
across config layers like every other key.

## Command vs skill vs agent

- A command is a **user-fired prompt** — it never triggers itself.
- If the knowledge should load when the *model* decides it's relevant, that's
  a **skill** (`opencode-config-and-skills`).
- If you find yourself giving a command its own model + permissions + long
  standing prompt, you're building an **agent** — make one and have the
  command merely dispatch to it via `agent:`.

## Checklist

1. Plural `commands/` dir; filename = `/name`.
2. Frontmatter parses; `description` present.
3. Shell injections are read-only and output-bounded.
4. Long/noisy operations get `subtask: true`.
5. Run opencode-dev's `scripts/validate.sh` — frontmatter parse
   (`opencode-frontmatter`), singular dir (`opencode-singular-dir`).

Source: [opencode.ai/docs/commands](https://opencode.ai/docs/commands).
Verified 2026-06-09.
