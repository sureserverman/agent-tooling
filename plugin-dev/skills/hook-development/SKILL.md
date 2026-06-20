---
name: hook-development
description: Use when authoring or debugging Claude Code hooks. Triggers on "PreToolUse hook", "PostToolUse hook", "session-end hook", "Stop hook infinite loop", "hooks.json".
---

# hook-development

Rules for writing correct, well-scoped Claude Code hooks. Read `references/events.md` for full
input/output schemas. Read `references/feedback-vs-blocking.md` before choosing to block.

> **Determinism boundary.** `hooks.json` structure, the 2026 event whitelist, `${CLAUDE_PLUGIN_ROOT}` usage, the Stop-loop guard, and timeout sanity are owned by `bash "${CLAUDE_PLUGIN_ROOT}/scripts/validate-hooks.sh" <hooks.json>` (it absorbed the old hook-linter + schema scripts). Scaffold a guarded hook with `scripts/scaffold-hook.sh`; exercise behavior with `scripts/test-hook.sh`. Run those first; reserve judgment for the feedback-vs-blocking decision.

> **Version compatibility — verify before shipping.** A handful of fields and env vars referenced
> in this skill and in `references/events.md` evolve between Claude Code releases. Confirm
> against `code.claude.com/docs/en/hooks` for your installed SDK version, in particular:
> - `output.path` field name on `PostToolUse` for file-edit tools (some SDK versions use `file_path` or `tool_input.file_path`).
> - `summary` field on `SessionEnd` input (presence and shape vary).
> - Prompt-rewriting on `UserPromptSubmit` (some versions only support `block`/`reason`, not in-place rewrite).
> - The Stop-loop guard env var name — `STOP_HOOK_ACTIVE` vs `CLAUDE_STOP_HOOK_ACTIVE`. Bash examples below use `STOP_HOOK_ACTIVE`; substitute if your SDK uses the prefixed form.
>
> Treat all bash snippets as templates, not drop-in code, until field names are confirmed.

## Reference map

| When you're… | Read first |
|---|---|
| Looking up an event's fields or maturity level | `references/events.md` |
| Deciding whether to block or inject feedback | `references/feedback-vs-blocking.md` |

## File and shape

Plugin hooks live in one file at the plugin root:

```
hooks/hooks.json
```

The file is a **JSON array** of hook entries. The schema mirrors the `hooks` block in
`settings.json` — one entry per event binding.

Minimal entry shape:

```json
[
  {
    "event": "PreToolUse",
    "matcher": { "tool": "Bash" },
    "command": "${CLAUDE_PLUGIN_ROOT}/hooks/guard-bash.sh"
  }
]
```

Key fields:

| Field | Required | Notes |
|---|---|---|
| `event` | yes | One of the names in the event catalogue below |
| `command` | yes (or `type:"prompt"`) | Shell command or prompt-hook config |
| `matcher` | depends on event | Filter by `tool`, `file`, `reason`, etc. |

**Always use `${CLAUDE_PLUGIN_ROOT}` for bundled script paths.** Relative paths break when the
plugin is installed outside the authoring directory.

## Event catalogue

32 events as of v2.1.170. Maturity labels: **widely-used** = proven in production across many
plugins; **documented** = in official docs, less battle-tested; **experimental** = subject to change.

### Lifecycle

| Event | Maturity | Notes |
|---|---|---|
| `SessionStart` | widely-used | Fires on new session or resume. Write env vars to `$CLAUDE_ENV_FILE`; can return `sessionTitle`, `initialUserMessage`, `watchPaths`, `reloadSkills` (v2.1.152+). |
| `Setup` | documented | Fires on `--init-only` / `--init` / `--maintenance` in `-p` mode. Matchers: `init`, `maintenance`. |
| `SessionEnd` | widely-used | Fires on termination. Matcher: `reason` — one of `clear`, `resume`, `logout`, `prompt_input_exit`, `other`. |
| `UserPromptSubmit` | widely-used | Fires when user submits a prompt. Can block, augment, or pass through. |
| `InstructionsLoaded` | documented | CLAUDE.md / `.claude/rules` loads. Matchers: `session_start`, `nested_traversal`, `path_glob_match`, `include`, `compact`. |
| `MessageDisplay` | documented | Display-only rewrite of assistant output via `displayContent` (v2.1.152+). |

### Tool execution

| Event | Maturity | Notes |
|---|---|---|
| `PreToolUse` | widely-used | Before a tool call. Return `permissionDecision: "deny"` to block, `"allow"` to approve, `"defer"` to escalate. Common: blocking `rm -rf`, guarding force-push. |
| `PostToolUse` | widely-used | After successful tool execution. Return `additionalContext` to inject feedback into the next turn (feedback-injection pattern). Common: lint/typecheck after file edits. |
| `PostToolUseFailure` | documented | After a tool error. Useful for recovery suggestions or alerting. |
| `PostToolBatch` | documented | After a parallel tool batch completes. Receives all results at once. |

### Permissions and failure

| Event | Maturity | Notes |
|---|---|---|
| `PermissionRequest` | documented | User-side permission prompt. Hook can auto-approve or auto-deny. |
| `PermissionDenied` | documented | Auto-mode classifier denial. Can return `{"retry": true}` to re-attempt. |
| `Stop` | documented | Claude finished its turn. Input includes `background_tasks` + `session_crons` (v2.1.149+). **See infinite-loop gotcha below.** |
| `StopFailure` | documented | Claude failed (rate limit, auth, billing). Good for alerting or retry logic. |
| `Notification` | documented | Incoming event from a monitor or MCP server. |

### Advanced / niche

| Event | Maturity | Notes |
|---|---|---|
| `UserPromptExpansion` | documented | Slash-command expansion. |
| `CwdChanged` | documented | Working directory changed. |
| `FileChanged` | documented | File modified outside Claude's tools. |
| `ConfigChange` | documented | Settings / enabled-plugin changes mid-session. |
| `SubagentStart` / `SubagentStop` | documented | Subagent lifecycle. |
| `TaskCreated` / `TaskCompleted` | documented | Tracked-task lifecycle. |
| `TeammateIdle` | documented | Agent-team teammate goes idle. |
| `WorktreeCreate` / `WorktreeRemove` | documented | Git worktree lifecycle. |
| `PreCompact` / `PostCompact` | documented | Context compaction. Matchers: `manual`, `auto`. |
| `Elicitation` / `ElicitationResult` | documented | MCP server requests user input / user responds. |

### Handler types

Five handler types (`SessionStart` and `Setup` support only `command` + `mcp_tool`):

| Type | Notes |
|---|---|
| `command` | Shell command — the default; deterministic and cheap |
| `http` | POSTs the event JSON to a URL |
| `mcp_tool` | Calls a tool on a configured MCP server |
| `prompt` | LLM yes/no evaluation; 30s default timeout |
| `agent` | Agentic verifier (experimental); 60s default timeout |

```json
{
  "event": "UserPromptSubmit",
  "type": "prompt",
  "prompt": "Check whether this prompt contains credentials or PII. If yes, return {\"block\": true, \"reason\": \"credential detected\"}."
}
```

Use `prompt`/`agent` only when bash decision logic is not expressive enough.

Hooks can also be scoped per-skill / per-agent via `hooks` frontmatter (plugin-shipped agents
ignore frontmatter hooks — see `agent-development`).

### Environment variables

`CLAUDE_PROJECT_DIR` (all hooks), `CLAUDE_PLUGIN_ROOT` (changes on update),
`CLAUDE_PLUGIN_DATA` (survives updates), `CLAUDE_ENV_FILE` (`SessionStart`/`Setup`/
`CwdChanged`/`FileChanged` only), `CLAUDE_EFFORT` (`low`–`max`, ~v2.1.141+),
`CLAUDE_CODE_REMOTE`. Any hook can return `terminalSequence` (v2.1.141+) to emit OSC
sequences to the terminal. Full table in `references/events.md`.

## Patterns

### PostToolUse feedback injection (linter)

Run a linter after edits and return errors as context rather than blocking the write.
See `references/feedback-vs-blocking.md` for why this beats blocking.

```json
{
  "event": "PostToolUse",
  "matcher": { "tool": "Edit", "file": "**/*.ts" },
  "command": "${CLAUDE_PLUGIN_ROOT}/hooks/eslint-feedback.sh"
}
```

`eslint-feedback.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail
# Hook receives tool output on stdin as JSON
FILE=$(jq -r '.output.path // empty' <<<"$1")
[ -z "$FILE" ] && exit 0
RESULT=$(eslint --format=compact "$FILE" 2>&1 || true)
[ -z "$RESULT" ] && exit 0
jq -n --arg ctx "$RESULT" '{"additionalContext": $ctx}'
```

### PreToolUse guard for dangerous bash

```json
{
  "event": "PreToolUse",
  "matcher": { "tool": "Bash" },
  "command": "${CLAUDE_PLUGIN_ROOT}/hooks/guard-bash.sh"
}
```

`guard-bash.sh`:

```bash
#!/usr/bin/env bash
CMD=$(jq -r '.input.command // empty' <<<"$1")
if echo "$CMD" | grep -qE '(rm\s+-rf\s+/|git push --force(-with-lease)? origin main)'; then
  jq -n '{"permissionDecision": "deny", "reason": "Blacklisted pattern matched"}'
  exit 0
fi
jq -n '{"permissionDecision": "allow"}'
```

### SessionEnd auto-capture

Archive the session to a vault or journal:

```json
{
  "event": "SessionEnd",
  "matcher": { "reason": "logout" },
  "command": "${CLAUDE_PLUGIN_ROOT}/hooks/session-capture.sh"
}
```

### UserPromptSubmit security scrub

Strip secrets from user input before the model sees them:

```json
{
  "event": "UserPromptSubmit",
  "command": "${CLAUDE_PLUGIN_ROOT}/hooks/secret-scrub.sh"
}
```

The hook receives the prompt text and returns a (possibly rewritten) prompt or a block decision.

## Anti-patterns

1. **`Stop` hook without `stop_hook_active` guard — infinite loop.** The #1 newbie bug. A `Stop`
   hook that itself triggers Claude's turn causes another `Stop`, forever.
   Always open every `Stop` hook script with:

   ```bash
   if [ "$STOP_HOOK_ACTIVE" = "true" ]; then exit 0; fi
   ```

2. **Blocking on error in PostToolUse hooks.** Returning a hard block from a linter silently
   cancels writes the user expected to succeed. Prefer feedback injection — return the error
   as `additionalContext` and let the model self-correct.

3. **Relative script paths in `command:`.** They break the moment the plugin is installed
   anywhere other than the authoring directory. Always use `${CLAUDE_PLUGIN_ROOT}/…`.

4. **Long-running hooks on hot events.** A 500 ms lint run on every `PostToolUse` for every
   Edit compounds across the session. Gate by `tool` name and `file` pattern to limit scope.

5. **Shell profile / rc-file output to stderr.** Hooks parse stdout as JSON. Anything that
   sources a profile (`~/.bashrc`, `/etc/profile`) or produces banner output to stderr can
   corrupt hook parsing. Run hook scripts with `env -i` or a minimal shebang that avoids
   profile sourcing.

## Targeting Cowork? Hooks behave differently there

If your plugin will be installed in **Claude Cowork**, hooks are a supported component as of June 2026 — but only in Cowork itself (grayed out in Claude web chat / Desktop Chat), and Anthropic publishes **no list of which events fire there**. Don't assume Claude Code's full 32-event set; test in Cowork, and see the `cowork-dev` sibling plugin (`cowork-plugin-development` skill) for the platform's component-support matrix.

When an event you need isn't available, redesign hooks as in-skill behavior:

- **PreToolUse policy hooks** → explicit confirmation steps inside skills ("Save? (yes / no / edit)").
- **SessionStart hooks** → a skill whose description picks up first-message signal ("show me what you do", "what is this").
- **Stop hooks** → closing-block discipline at the end of each long-running skill.

Full guidance — including the other Cowork-specific patterns (multilingual triggers, connector-aware enrichment, distribution paths and limits) — lives in the `cowork-dev` sibling plugin. Read its `cowork-plugin-development` skill before shipping a hook-heavy plugin to Cowork.

## Sources

- code.claude.com/docs/en/hooks (canonical event reference; verified 2026-06-09, v2.1.170)
- code.claude.com/docs/en/hooks-guide
- Community examples: github.com/wshobson/agents, github.com/obra/superpowers
