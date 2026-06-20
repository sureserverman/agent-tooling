# Command Frontmatter Reference

Full field reference for Claude Code slash command frontmatter. All fields sit inside the YAML block at the top of the `.md` file.

```
---
description: One-line summary shown in /help
argument-hint: [arg1] [arg2]
allowed-tools: ["Read", "Bash"]
model: sonnet
---
```

---

## Fields

### `description`

**Required.** One-line summary shown when the user runs `/help` or browses available commands.

- Keep it under ~80 characters — longer values get truncated in the UI.
- Lead with a verb: "Review", "Scaffold", "Run", "Generate".
- Do not repeat the command name — the name appears separately.

```yaml
description: Review a file for style and security issues
```

---

### `argument-hint`

**Optional, but required whenever the command accepts arguments.**

Shown in the input box as a placeholder so the user knows what to type. Uses bracket notation by convention; the brackets are decorative, not syntax.

```yaml
argument-hint: [path/to/file]
argument-hint: [mode] [--flags "..."]
argument-hint: [component-type]
```

Rules:
- One hint per positional group.
- Use `"..."` to signal a quoted multi-word value.
- Omit only on commands that take no arguments at all.

---

### `allowed-tools`

**Optional.** JSON array of tool names the command is permitted to call while running. If omitted, the command inherits the parent session's full tool set.

```yaml
allowed-tools: ["Read", "Bash"]
allowed-tools: ["Read", "Write", "Edit"]
allowed-tools: ["AskUserQuestion", "Read", "Bash"]
```

Supported tool names (non-exhaustive):

| Tool | What it does |
|---|---|
| `Read` | Read files from disk |
| `Write` | Write files to disk |
| `Edit` | Make targeted edits to existing files |
| `Bash` | Execute shell commands |
| `AskUserQuestion` | Prompt the user for input interactively |
| `WebFetch` | Fetch a URL |
| `Grep` | Search file contents |
| `Glob` | Enumerate file paths by pattern |

Guidelines:
- List only tools the command body actually uses.
- Do not use `["*"]` — it bypasses all restriction.
- `AskUserQuestion` must be listed explicitly when the body uses it; it is not included by default.
- A command cannot grant tools that the parent session does not already have.

---

### `model`

**Optional.** Pins the model used for this command's execution.

| Value | Meaning |
|---|---|
| `haiku` | Fastest, cheapest. Use for mechanical sweeps, lint passes, bulk file ops. |
| `sonnet` | Balanced. Default for most commands. |
| `opus` | Highest capability. Reserve for complex reasoning and multi-file planning. |
| `inherit` | Use whatever model the parent session is currently running. |
| Full model ID | Pin to a specific release, e.g. `claude-opus-4-5-20251201`. |

```yaml
model: haiku      # lint sweep — cheap and fast
model: sonnet     # default authoring command
model: opus       # architecture planning command
model: inherit    # general-purpose command, follows parent
```

If `model` is omitted, behavior is implementation-defined — do not rely on it. Always set explicitly.

---

### `disable-model-invocation`

**Optional, boolean (default `false`).** When `true`, the command runs only when the user types `/name` explicitly — the model cannot trigger it through the `SlashCommand` tool.

```yaml
disable-model-invocation: true   # e.g. a deploy/approval command you never want auto-run
```

Use it for destructive or approval-gated commands. Leave it off for everyday helper commands you want the model to reach for.

---

## Body mechanics

**`$ARGUMENTS`** — verbatim string the user typed after the command name, substituted into the body at invocation time. `/my-command src/main.rs` → `$ARGUMENTS` is `src/main.rs`.

**`$1`, `$2`, …** — individual whitespace-separated arguments. `/deploy staging v2` → `$1` is `staging`, `$2` is `v2`. Use these when the command has distinct positional slots; use `$ARGUMENTS` when you want the whole raw string. Quote them in bash blocks just like `$ARGUMENTS`.

Shell injection rule: always quote inside bash blocks.

```bash
cat "$ARGUMENTS"   # safe
cat $ARGUMENTS     # UNSAFE — injection if value contains spaces or special chars
```

**`@<path>` file references** — `@src/lib.rs` or `@$ARGUMENTS` loads the file into context at invocation time. If the path does not exist, the reference expands silently to nothing — no error is raised.

**Executable bash blocks** — only blocks with an explicit `Run:` instruction ahead of them are executed. Unmarked fenced blocks and inline backticks are rendered as text only.

```
Run: git diff --name-only HEAD
```

---

## Complete examples

**Interactive guided command** — collects missing input via `AskUserQuestion`:

```markdown
---
description: Scaffold a new plugin component (skill, subagent, or command)
argument-hint: [component-type]
allowed-tools: ["AskUserQuestion", "Read", "Write"]
model: sonnet
---

If $ARGUMENTS is empty, call AskUserQuestion: "Which component type? (skill / subagent / command)"
Scaffold the appropriate skeleton under the current plugin directory.
Read one neighbor file for style before writing. Leave TODO markers for caller-supplied content.
```

**Cheap lint sweep** — mechanical pass, pinned to haiku:

```markdown
---
description: Run a fast style lint over every *.md file in the project
allowed-tools: ["Bash", "Read"]
model: haiku
---

Run: find . -name "*.md" -not -path "./.git/*"

For each file: check frontmatter has name + description; no line over 120 chars; no trailing whitespace.
Report as: <file>:<line>: <issue>. Do not auto-fix.
```

**File-targeted review** — loads file into context via `@$ARGUMENTS`:

```markdown
---
description: Review a single command file for authoring quality
argument-hint: [path/to/command.md]
allowed-tools: ["Read"]
model: sonnet
---

Read @$ARGUMENTS. Report one finding per line for: missing argument-hint, unquoted $ARGUMENTS in bash
blocks, allowed-tools ["*"], absent model field, hardcoded absolute paths.
Output format: <issue-type>: <description>. If none: OK
```
