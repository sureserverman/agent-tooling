# Codex hooks reference

Facts verified 2026-06-09 against [developers.openai.com/codex/hooks](https://developers.openai.com/codex/hooks), Codex CLI v0.139.0. Hooks engine shipped in v0.114.0 (March 11, 2026); `UserPromptSubmit` added v0.116, `PostToolUse` ~v0.117.

## The 10 lifecycle events

| Event | Fires |
|---|---|
| `SessionStart` | New session begins |
| `SubagentStart` | A subagent thread spawns |
| `UserPromptSubmit` | User submits a prompt, before the model sees it |
| `PreToolUse` | Before a tool call executes — can block or rewrite input |
| `PermissionRequest` | A permission prompt is about to be shown |
| `PostToolUse` | After a tool call returns |
| `PreCompact` | Before context compaction |
| `PostCompact` | After context compaction |
| `SubagentStop` | A subagent thread finishes |
| `Stop` | The main agent turn ends |

Anything else in a hooks file is silently ignored by Codex — the deterministic lane flags unknown names as `codex-hook-unknown-event` (warning).

## Locations and precedence

Resolution order (earlier wins for conflicting matchers):

1. `~/.codex/hooks.json` — user JSON
2. `[hooks]` in `~/.codex/config.toml` — user TOML
3. `.codex/hooks.json` — project JSON
4. `[hooks]` in `.codex/config.toml` — project TOML

Plugins bundle hooks as `hooks/hooks.json` inside the plugin; those join the chain when the plugin is enabled (see the codex-plugin-development skill).

## File shapes

JSON mirrors Claude Code's `hooks.json`:

```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "shell",
        "hooks": [
          {
            "type": "command",
            "command": "/usr/local/bin/audit-tool-call.sh",
            "timeout": 10,
            "statusMessage": "Auditing tool call…"
          }
        ]
      }
    ]
  }
}
```

TOML equivalent in config.toml — one `[[hooks.<Event>]]` array entry per matcher group:

```toml
[[hooks.PreToolUse]]
matcher = "shell"

[[hooks.PreToolUse.hooks]]
type = "command"
command = "/usr/local/bin/audit-tool-call.sh"
timeout = 10
statusMessage = "Auditing tool call…"
```

## I/O contract

**stdin** — one JSON object per invocation:

| Field | Meaning |
|---|---|
| `session_id` | Current session |
| `cwd` | Working directory |
| `hook_event_name` | Which of the 10 events fired |
| `model` | Active model slug |
| `permission_mode` | Current approval posture |
| `turn_id` | Current turn |

plus event-specific payload (tool name/input for `PreToolUse`/`PostToolUse`, etc.).

**Exit codes:**

| Exit | Meaning |
|---|---|
| `0` | OK — stdout may carry the JSON below |
| `2` | **Block** the action — stderr is shown to the model as the reason |
| other | Non-blocking error; logged |

**stdout JSON** (exit 0):

| Key | Effect |
|---|---|
| `continue` (bool) | `false` stops the turn |
| `stopReason` | Shown when stopping |
| `systemMessage` | Injected as a system note |
| `suppressOutput` | Hide stdout from the transcript |
| `hookSpecificOutput.permissionDecision` | `allow` \| `deny` (PreToolUse / PermissionRequest) |
| `hookSpecificOutput.updatedInput` | Rewrite the tool input (PreToolUse) |

## Trust model — why your hook "doesn't fire"

**Unmanaged command hooks must be approved via `/hooks` before they run.** Until a user reviews and trusts them, they are silently skipped — the single most common "hooks are broken" report. Consequences:

- Plugin/repo docs must tell users to run `/hooks` and trust the hook after install.
- `--dangerously-bypass-hook-trust` skips review for **one invocation** — CI escape hatch only.
- Enterprises can pin `allow_managed_hooks_only` in `requirements.toml` (valid only there) so only managed hooks ever execute.

## Legacy: notify

`notify = ["python3", "/path/notify.py"]` predates the hooks engine: it execs the command with one JSON argument and fires **only** on `agent-turn-complete`. Keep it for simple desktop notifications; use hooks for everything else. It is distinct from `tui.notifications` (terminal bell/toast settings) — three different mechanisms, don't conflate them.

## Sources

- OpenAI, *Hooks* — events, locations, precedence, contracts, trust model — [developers.openai.com/codex/hooks](https://developers.openai.com/codex/hooks). Verified 2026-06-09 (Codex CLI v0.139.0).
- OpenAI, *Changelog* — engine v0.114.0, UserPromptSubmit v0.116, PostToolUse ~v0.117 — [developers.openai.com/codex/changelog](https://developers.openai.com/codex/changelog). Verified 2026-06-09.
