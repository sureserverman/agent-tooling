# Hook Events Reference

Current event list: **32 events** as of Claude Code v2.1.170 (verified against
`code.claude.com/docs/en/hooks`, 2026-06-09).

Maturity labels used throughout:
- **widely-used** — proven across many production plugins; stable API.
- **documented** — covered in official docs; real-world coverage is thinner.
- **experimental** — subject to change; test before shipping.

> **Version compatibility — verify before shipping.** Several field names and env vars below
> evolve between Claude Code releases. Confirm against `code.claude.com/docs/en/hooks` for
> your installed SDK version, in particular:
> - `output.path` field name on `PostToolUse` for file-edit tools (some SDK versions use `file_path` or `tool_input.file_path`).
> - `summary` field on `SessionEnd` input (presence and shape vary).
> - Prompt-rewriting on `UserPromptSubmit` (some versions only support `block`/`reason`, not in-place rewrite).
> - The Stop-loop guard env var name — `STOP_HOOK_ACTIVE` vs `CLAUDE_STOP_HOOK_ACTIVE`. Bash examples use `STOP_HOOK_ACTIVE`; substitute if your SDK uses the prefixed form.
>
> Treat all bash snippets as templates, not drop-in code, until field names are confirmed.

---

## Handler types

Five handler types as of v2.1.170:

| Type | Runs | Default timeout | Notes |
|---|---|---|---|
| `command` | Shell command | 60s | The workhorse; deterministic, cheap |
| `http` | POSTs the event JSON to a URL | — | Remote policy services, audit sinks |
| `mcp_tool` | An MCP tool call | — | Reuse an already-configured MCP server |
| `prompt` | Single LLM yes/no evaluation | 30s | Nuanced judgment; slower, costs tokens |
| `agent` | Agentic verifier with tool access | 60s | Experimental; multi-step verification |

`SessionStart` and `Setup` support only `command` and `mcp_tool`.

Hooks can also be scoped per-skill and per-agent via `hooks` frontmatter in the SKILL.md /
agent file (plugin-shipped **agents** ignore frontmatter hooks — see the `agent-development`
skill).

## Environment variables

| Variable | Scope | Notes |
|---|---|---|
| `CLAUDE_PROJECT_DIR` | all hooks | Project root at invocation |
| `CLAUDE_PLUGIN_ROOT` | plugin hooks | Install dir; **changes on plugin update** |
| `CLAUDE_PLUGIN_DATA` | plugin hooks | Persistent data dir; survives updates |
| `CLAUDE_ENV_FILE` | `SessionStart`, `Setup`, `CwdChanged`, `FileChanged` only | Write `KEY=VALUE` lines for session-persistent env vars |
| `CLAUDE_EFFORT` | all hooks (~v2.1.141+) | `low`\|`medium`\|`high`\|`xhigh`\|`max` |
| `CLAUDE_CODE_REMOTE` | all hooks | Set when running in a remote/cloud session |

**Cross-event output field:** `terminalSequence` (v2.1.141+) — emit OSC escape sequences to
the hosting terminal (titles, notifications) from any hook's JSON output.

---

## Lifecycle events

### `SessionStart` — widely-used

Fires when a session begins (new or resumed).

**Input fields:**

| Field | Type | Description |
|---|---|---|
| `session_id` | string | Unique session identifier |
| `resumed` | boolean | `true` if this is a resumed session |

**Output fields (optional):**

| Field | Type | Description |
|---|---|---|
| `env` | object | Key-value pairs to write to `$CLAUDE_ENV_FILE` for persistence |
| `sessionTitle` | string | Set the session title (v2.1.152+) |
| `initialUserMessage` | string | Pre-fill the first user message (v2.1.152+) |
| `watchPaths` | array | Paths to watch for `FileChanged` events (v2.1.152+) |
| `reloadSkills` | boolean | Force a skill re-scan (v2.1.152+) |

Handler types: `command` and `mcp_tool` only.

**Use-case:** Load per-project config, set `PROJECT_ROOT`, write auth tokens to the env file
so downstream hooks can read them without re-computing.

**Worked example:**

```bash
#!/usr/bin/env bash
# hooks/session-init.sh
PROJECT=$(jq -r '.session_id' <<<"$1")
jq -n --arg root "$PWD" '{"env": {"PROJECT_ROOT": $root}}'
```

(The `STOP_HOOK_ACTIVE` guard is for `Stop` hooks only — see that section below; it does not apply to `SessionStart`.)

```json
{ "event": "SessionStart", "command": "${CLAUDE_PLUGIN_ROOT}/hooks/session-init.sh" }
```

---

### `Setup` — documented

Fires when Claude Code runs with `--init-only`, `--init`, or `--maintenance` in `-p` mode —
the one-shot environment-preparation entry point.

**Matchers:** `init`, `maintenance`.
**Handler types:** `command` and `mcp_tool` only.
**Output:** Same env-file mechanism as `SessionStart` (`$CLAUDE_ENV_FILE` is available).

**Use-case:** Install toolchains, warm caches, or run repo maintenance in CI before the
real session starts.

---

### `InstructionsLoaded` — documented

Fires when a `CLAUDE.md` or `.claude/rules` file is loaded into context.

**Matchers:** `session_start`, `nested_traversal`, `path_glob_match`, `include`, `compact`.
**Input:** `path` (string), `trigger` (string, matches the matcher values).
**Output:** `additionalContext` (string).

**Use-case:** Audit which instruction files actually load, inject supplements when a
specific rules file appears.

---

### `MessageDisplay` — documented (v2.1.152+)

Fires before an assistant message is rendered. Display-only rewrite — the transcript and
model context are unchanged.

**Input:** `content` (string, the message about to display).
**Output:** `displayContent` (string, replacement text for display only).

**Use-case:** Redact secrets from displayed output, add display-side annotations.

---

### `SessionEnd` — widely-used

Fires when the session terminates.

**Input fields:**

| Field | Type | Description |
|---|---|---|
| `session_id` | string | Session identifier |
| `reason` | string | One of `clear`, `resume`, `logout`, `prompt_input_exit`, `other` |
| `summary` | string | Brief model-generated session summary (may be empty) |

**Matcher:** `reason` — filter to specific termination causes.

**Output fields:** None expected; hook runs for side-effects only.

**Use-case:** Archive a session transcript to a vault, trigger a journal entry, flush a
metrics buffer.

**Worked example:**

```bash
#!/usr/bin/env bash
# hooks/session-capture.sh
REASON=$(jq -r '.reason' <<<"$1")
SUMMARY=$(jq -r '.summary // ""' <<<"$1")
DATE=$(date -u +%Y-%m-%d)
echo "[$DATE] session-end reason=$REASON" >> ~/.claude/session-log.txt
[ -n "$SUMMARY" ] && echo "$SUMMARY" >> ~/.claude/session-log.txt
```

```json
{
  "event": "SessionEnd",
  "matcher": { "reason": "logout" },
  "command": "${CLAUDE_PLUGIN_ROOT}/hooks/session-capture.sh"
}
```

---

### `UserPromptSubmit` — widely-used

Fires immediately after the user submits a prompt, before the model processes it.

**Input fields:**

| Field | Type | Description |
|---|---|---|
| `prompt` | string | Raw user prompt text |
| `session_id` | string | Current session |

**Output fields (optional):**

| Field | Type | Description |
|---|---|---|
| `prompt` | string | Rewritten prompt (replaces the original) |
| `block` | boolean | If `true`, prevents the prompt from reaching the model |
| `reason` | string | Shown to user when `block` is `true` |

**Use-case:** Scrub secrets/PII from prompts, enforce prompt policies, inject per-turn context.

**Worked example — secret scrub:**

```bash
#!/usr/bin/env bash
# hooks/secret-scrub.sh
PROMPT=$(jq -r '.prompt' <<<"$1")
# Redact anything that looks like AWS keys
CLEAN=$(echo "$PROMPT" | sed 's/AKIA[0-9A-Z]\{16\}/[REDACTED_AWS_KEY]/g')
if [ "$CLEAN" != "$PROMPT" ]; then
  jq -n --arg p "$CLEAN" '{"prompt": $p}'
else
  exit 0   # no change needed
fi
```

---

## Tool execution events

### `PreToolUse` — widely-used

Fires before a tool call executes. The hook can allow, deny, or defer the call.

**Input fields:**

| Field | Type | Description |
|---|---|---|
| `tool` | string | Tool name (e.g., `Bash`, `Edit`, `Write`) |
| `input` | object | Tool-specific input (e.g., `command` for Bash, `path` for Edit) |
| `session_id` | string | Current session |

**Matcher:** `tool` — bind only to specific tools.

**Output fields:**

| Field | Type | Description |
|---|---|---|
| `permissionDecision` | string | `"allow"`, `"deny"`, or `"defer"` |
| `reason` | string | Shown to user/model on deny |

**Use-case:** Block destructive commands, require confirmation for sensitive operations,
enforce branch-protection rules.

**Worked example — block force-push to main:**

```bash
#!/usr/bin/env bash
# hooks/guard-bash.sh
CMD=$(jq -r '.input.command // empty' <<<"$1")
if echo "$CMD" | grep -qE 'git push --force(-with-lease)? origin main'; then
  jq -n '{"permissionDecision": "deny", "reason": "Force-push to main is blocked by policy."}'
  exit 0
fi
jq -n '{"permissionDecision": "allow"}'
```

```json
{
  "event": "PreToolUse",
  "matcher": { "tool": "Bash" },
  "command": "${CLAUDE_PLUGIN_ROOT}/hooks/guard-bash.sh"
}
```

---

### `PostToolUse` — widely-used

Fires after a tool call completes successfully.

**Input fields:**

| Field | Type | Description |
|---|---|---|
| `tool` | string | Tool name |
| `input` | object | Original tool input |
| `output` | object | Tool result (e.g., `path`, `content` for file edits) |
| `session_id` | string | Current session |

**Matcher:** `tool`, `file` — narrow to specific tools or file patterns.

**Output fields:**

| Field | Type | Description |
|---|---|---|
| `additionalContext` | string | Injected into the next model turn as context |

**Use-case:** Run linters, type-checkers, or tests after edits and surface errors without
blocking the write (feedback-injection pattern). See `feedback-vs-blocking.md`.

**Worked example — mypy feedback injection:**

```bash
#!/usr/bin/env bash
# hooks/mypy-feedback.sh
FILE=$(jq -r '.output.path // empty' <<<"$1")
[[ "$FILE" != *.py ]] && exit 0
RESULT=$(mypy "$FILE" 2>&1 || true)
[ -z "$RESULT" ] && exit 0
jq -n --arg ctx "mypy output:\n$RESULT" '{"additionalContext": $ctx}'
```

```json
{
  "event": "PostToolUse",
  "matcher": { "tool": "Edit", "file": "**/*.py" },
  "command": "${CLAUDE_PLUGIN_ROOT}/hooks/mypy-feedback.sh"
}
```

---

### `PostToolUseFailure` — documented

Fires when a tool call returns an error.

**Input fields:** Same as `PostToolUse`, plus:

| Field | Type | Description |
|---|---|---|
| `error` | string | Error message from the tool |

**Output fields:** Same as `PostToolUse` (`additionalContext`).

**Use-case:** Suggest recovery actions, alert on repeated failures, log tool errors to an
external sink.

---

### `PostToolBatch` — documented

Fires after a batch of parallel tool calls all complete.

**Input fields:**

| Field | Type | Description |
|---|---|---|
| `results` | array | Array of `{tool, input, output, error}` objects |
| `session_id` | string | Current session |

**Output fields:** `additionalContext` (string).

**Use-case:** Aggregate lint results across multiple files edited in parallel, avoiding
per-file noise.

---

## Permissions and failure events

### `PermissionRequest` — documented

Fires when a permission prompt is shown to the user. Hook can resolve it automatically.

**Input fields:**

| Field | Type | Description |
|---|---|---|
| `tool` | string | Tool requesting permission |
| `input` | object | Tool input |
| `permission` | string | The specific permission being requested |

**Output fields:**

| Field | Type | Description |
|---|---|---|
| `decision` | string | `"approve"` or `"deny"` |
| `reason` | string | Optional justification |

**Use-case:** Auto-approve allowlisted tools for CI environments; auto-deny network access
in air-gapped sessions.

---

### `PermissionDenied` — documented

Fires when the auto-mode permission classifier denies a tool call (no user prompt shown).

**Input:** `tool` (string), `input` (object), `denial_reason` (string).

**Output fields:**

| Field | Type | Description |
|---|---|---|
| `retry` | boolean | `true` re-attempts the tool call (e.g. after the hook fixed the precondition) |
| `additionalContext` | string | Explain the denial to the model |

**Use-case:** Recover from overzealous classifier denials in automation, log denied
operations for policy tuning.

---

### `Stop` — documented

Fires when Claude finishes its turn (non-blocking by default).

**Input fields:**

| Field | Type | Description |
|---|---|---|
| `session_id` | string | Current session |
| `turn_id` | string | Completed turn identifier |
| `background_tasks` | array | Still-running background tasks (v2.1.149+) |
| `session_crons` | array | Active session cron jobs (v2.1.149+) |

**Output fields:** None.

**CRITICAL — infinite loop guard:** Any action a `Stop` hook takes that causes Claude to
run another turn will trigger another `Stop`, recursively. Always check:

```bash
if [ "$STOP_HOOK_ACTIVE" = "true" ]; then exit 0; fi
```

**Use-case:** Post-turn metrics, structured output extraction, triggering downstream pipelines
after Claude's response is complete.

---

### `StopFailure` — documented

Fires when Claude's turn ends with a failure (rate limit, auth error, billing issue).

**Input fields:**

| Field | Type | Description |
|---|---|---|
| `session_id` | string | Current session |
| `error_code` | string | Machine-readable failure category |
| `error_message` | string | Human-readable description |

**Output fields:** None.

**Use-case:** Alert via webhook, write to a dead-letter log, trigger a retry workflow.

---

### `Notification` — documented

Fires when an external event arrives from a monitor or MCP server.

**Input fields:**

| Field | Type | Description |
|---|---|---|
| `source` | string | Monitor or MCP server name |
| `payload` | object | Arbitrary notification payload |

**Output fields:** `additionalContext` (string) to surface the notification in the next turn.

---

## Advanced / niche events

### `UserPromptExpansion` — documented

Fires during slash-command expansion, before the expanded prompt is submitted.

**Input:** `command` (string, the slash command), `args` (string).
**Output:** `prompt` (string, the expanded prompt to use).

---

### `CwdChanged` — documented

Fires when the working directory changes.

**Input:** `old_cwd` (string), `new_cwd` (string).
**Output:** `additionalContext` (string).

**Use-case:** Switch active project context, reload per-directory env vars.

---

### `FileChanged` — documented

Fires when a file is modified outside Claude's own tools (e.g., by another process).

**Input:** `path` (string), `change_type` (string: `created`, `modified`, `deleted`).
**Output:** `additionalContext` (string).

**Use-case:** Notify Claude that a build artifact changed, trigger re-reads.

---

### `SubagentStart` / `SubagentStop` — documented

Fire at the start and end of a subagent's lifecycle.

**Input:** `subagent_id` (string), `subagent_name` (string), `session_id` (string).
`SubagentStop` additionally carries `background_tasks` and `session_crons` (v2.1.149+),
same as `Stop`.
**Output:** None.

**Use-case:** Scope resource allocation/cleanup to subagent lifetime, emit tracing spans.

---

## Compaction events

### `PreCompact` / `PostCompact` — documented

Fire before and after context compaction.

**Matchers:** `manual`, `auto`.
**Input:** `session_id` (string), `trigger` (string: `manual` or `auto`).
**Output:** `additionalContext` (string, `PostCompact` — re-inject must-keep context).

**Use-case:** Snapshot state before compaction, re-prime critical context after it.

---

## Task and team events

### `TaskCreated` / `TaskCompleted` — documented

Fire when a tracked task is created or completed.

**Input:** `task_id` (string), `description` (string), `session_id` (string).
**Output:** `additionalContext` (string).

**Use-case:** Mirror Claude's task list into an external tracker.

---

### `TeammateIdle` — documented

Fires when an agent-team teammate goes idle (agent teams feature).

**Input:** `teammate_id` (string), `session_id` (string).
**Output:** `additionalContext` (string) — e.g. assign follow-up work.

---

## Config and workspace events

### `ConfigChange` — documented

Fires when Claude Code configuration changes mid-session (settings, enabled plugins).

**Input:** `source` (string), `changes` (object).
**Output:** `additionalContext` (string).

---

### `WorktreeCreate` / `WorktreeRemove` — documented

Fire when a git worktree is created or removed (e.g. `EnterWorktree`/`ExitWorktree`).

**Input:** `worktree_path` (string), `branch` (string), `session_id` (string).
**Output:** None.

**Use-case:** Provision per-worktree env files, clean up worktree-scoped caches.

---

## MCP user-input events

### `Elicitation` / `ElicitationResult` — documented

Fire when an MCP server requests user input (elicitation) and when the user responds.

**Input:** `server` (string), `prompt` (string); `ElicitationResult` adds `response`.
**Output:** None (observe-only); use for audit logging of MCP-driven prompts.

---

## Sources

- code.claude.com/docs/en/hooks (canonical event reference; verified 2026-06-09, v2.1.170)
