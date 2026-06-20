---
name: command-development
description: Use when authoring Claude Code slash commands. Triggers on "command frontmatter", "$ARGUMENTS in commands", "argument-hint", "allowed-tools for command".
---

# command-development

Decision rules for authoring slash commands that are tight, secure, and well-scoped. Consult `references/frontmatter.md` when you need the full field reference.

> **Determinism boundary.** Frontmatter fields, the `model` enum, `allowed-tools` scoping, `$ARGUMENTS` quoting, and hardcoded-path checks are owned by `bash "${CLAUDE_PLUGIN_ROOT}/scripts/validate-command.sh" <command.md>`. Scaffold a valid skeleton with `scripts/scaffold-command.sh`. Run the validator first; reserve your attention for prompt tightness and whether the tool set and model actually fit the job.

## Reference map

| When you're… | Read first |
|---|---|
| Filling out command frontmatter fields | `references/frontmatter.md` |
| Choosing a model tier | Section: Model selection |
| Building an interactive flow | Section: Patterns |
| Reviewing a command for problems | Section: Anti-patterns |

## File locations

| Context | Path | Invocation |
|---|---|---|
| Plugin command | `commands/<name>.md` | `/<name>` or `/<plugin>:<name>` when namespaced |
| Project command | `.claude/commands/<name>.md` | `/<name>` |
| User command | `~/.claude/commands/<name>.md` | `/<name>` |

Plugins always ship the first kind. Project and user commands are the caller's concern.

## Non-negotiable rules

These apply to every command. No exceptions.

1. **`$ARGUMENTS` in executable bash blocks must be quoted.** Unquoted substitution is shell injection. Use `"$ARGUMENTS"` or parse into named vars first.
2. **`allowed-tools` must be restricted to what the command actually needs.** `["*"]` defeats the entire purpose of the field.
3. **`argument-hint` is required whenever the command accepts arguments.** Without it users can't tell what to type.
4. **No hardcoded absolute paths.** Use `${CLAUDE_PROJECT_DIR}` or paths relative to pwd.
5. **Pin a model when the command is clearly cheap or clearly heavy.** Don't leave an expensive reasoning task running on sonnet by accident, or a lint sweep burning opus tokens.
6. **Body prose must be decision-rule tight.** Vague prompt bodies cause the model to wander. Every sentence should constrain behavior, not describe it.

## Model selection

| Model | Use when |
|---|---|
| `haiku` | Bulk file ops, lint passes, search sweeps — mechanical work, many tokens |
| `sonnet` | Balanced authoring and review — most commands land here |
| `opus` | Complex multi-step reasoning, architecture calls, planning across many files |
| `inherit` | General-purpose commands where the parent session's tier is the right default |

Default to `sonnet` if uncertain. Explicitly set `inherit` only for commands that genuinely work at any tier.

## Patterns

### Guided flow
Use `AskUserQuestion` in the body to collect missing parameters interactively before acting. Must be listed in `allowed-tools`. Route on the answer with an explicit if/else block in the prompt body.

```
---
description: Scaffold a new plugin component
argument-hint: [component-type]
allowed-tools: ["AskUserQuestion", "Write", "Read"]
model: sonnet
---

If $ARGUMENTS is empty, call AskUserQuestion to ask the user which component type
they want (skill / subagent / command). Then scaffold the appropriate skeleton.
```

### Multi-arg parsing
Use a structured `argument-hint` to signal the expected shape. Parse at the top of the body.

```
---
description: Run a targeted audit pass
argument-hint: [mode] [--tabs "tab1,tab2"]
allowed-tools: ["Bash", "Read"]
model: haiku
---

Parse $ARGUMENTS: first token is mode (lint | types | deps), remainder are flags.
Run the corresponding check and report findings only — no auto-fixes.
```

### File-targeted command
Load the target file into context via `@$ARGUMENTS` so the model operates on its contents.

```
---
description: Review a single file for style issues
argument-hint: [path/to/file]
allowed-tools: ["Read"]
model: sonnet
---

Review the file at @$ARGUMENTS. Report: missing argument-hint, vague body prose,
shell injection risk, overly broad allowed-tools. One finding per line.
```

## Anti-patterns

- **`allowed-tools: ["*"]`** — unrestricted tool access. Restrict to the exact tools the body uses.
- **Unquoted `$ARGUMENTS` in bash blocks** — shell injection. Always quote.
- **Hardcoded `/home/user/...` or `/Users/...` paths** — breaks on other machines. Use `${CLAUDE_PROJECT_DIR}`.
- **Long, narrative prompt body** — model loses focus. Write decision rules, not prose.
- **Missing `argument-hint` on a command that takes args** — users see a blank input box.
- **`model: opus` on every command** — wastes tokens. Reserve opus for genuinely hard cases.
- **`model: haiku` on a reasoning-heavy command** — output quality degrades silently.
- **Bash blocks without explicit run-instructions** — inline backtick commands are not executed; only blocks marked with `Run: ...` are.

## Gotchas

1. **Bash backticks in the body are not executed.** Only fenced blocks with an explicit `Run:` instruction ahead of them trigger execution. Unmarked code blocks are shown as text.
2. **`@<path>` file references are resolved at invocation time.** If the path doesn't exist, the reference silently expands to nothing — no error. Validate the path in the body prompt.
3. **`allowed-tools` applies only while the command runs.** The parent session's tool set is unaffected. A command cannot grant tools the parent session doesn't have.
4. **Namespaced commands (`/plugin:name`) require the plugin to be installed.** Project-local commands under `.claude/commands/` do not need a plugin manifest.
5. **`model: inherit` does not mean "no preference".** It explicitly means "use the parent session's active model". If the parent is already running haiku, the command runs on haiku too.

## Related

- Authoring a skill: `plugin-dev:skill-development`
- Full frontmatter reference: `references/frontmatter.md`
- Structuring a plugin: `plugin-dev:plugin-structure`
