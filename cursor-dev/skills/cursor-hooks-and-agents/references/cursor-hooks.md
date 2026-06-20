# Cursor hooks — locations, schema, events, protocol (verified 2026-06-09, Cursor 3.7)

Hooks are deterministic interceptors: external programs (or LLM-evaluated
prompts) that run at lifecycle events and can observe, block, rewrite, or
extend what the agent does. Unlike rules/skills, the model cannot ignore them.

## Config locations and priority

Highest priority first; all matching configs are considered, higher levels
win on conflict:

| Level | Location |
|---|---|
| 1. Enterprise (MDM) | macOS `/Library/Application Support/Cursor/hooks.json` · Linux `/etc/cursor/hooks.json` · Windows `C:\ProgramData\Cursor\hooks.json` |
| 2. Team | Cursor dashboard (admin-managed) |
| 3. Project | `.cursor/hooks.json` |
| 4. User | `~/.cursor/hooks.json` |

## Schema

```json
{
  "version": 1,
  "hooks": {
    "beforeShellExecution": [
      {
        "command": "./hooks/shell-guard.sh",
        "type": "command",
        "timeout": 30,
        "failClosed": true
      }
    ],
    "stop": [
      {
        "command": "Check whether tests were run; if not, ask the agent to run them",
        "type": "prompt",
        "loop_limit": 3
      }
    ]
  }
}
```

- **`version`** — required integer (currently `1`). cursor-dev's validator
  errors when missing or non-integer.
- **`hooks`** — map of camelCase event name → array of hook entries.
- Per-entry keys:
  - `command` — executable + args (command type) or the natural-language
    condition (prompt type).
  - `type` — `"command"` (run a program) or `"prompt"` (LLM-evaluated
    natural-language condition; the event payload is available as
    `$ARGUMENTS` inside the prompt text).
  - `timeout` — seconds.
  - `loop_limit` — max consecutive firings for `stop`/`subagentStop`
    (default **5**). This is the built-in infinite-stop-loop guard — no
    manual `stop_hook_active` bookkeeping as in Claude Code.
  - `failClosed` — when `true`, a hook crash/timeout is treated as deny
    instead of the default fail-open.
  - `matcher` — restricts which tool/event instances the hook fires for.

## Event catalog (~22, all camelCase)

| Family | Events | Notes |
|---|---|---|
| Session | `sessionStart`, `sessionEnd` | |
| Workspace | `workspaceOpen` | May return `{"pluginPaths": ["/abs/path", …]}` to inject local plugins |
| Tool use | `preToolUse`, `postToolUse`, `postToolUseFailure` | `preToolUse` may rewrite input |
| Shell | `beforeShellExecution`, `afterShellExecution` | The shell-specific guard pair |
| MCP | `beforeMCPExecution`, `afterMCPExecution` | MCP-call-specific pair |
| File I/O | `beforeReadFile`, `afterFileEdit` | `beforeReadFile` enables read-redaction |
| Tab (autocomplete) | `beforeTabFileRead`, `afterTabFileEdit` | No Claude Code equivalent |
| Prompting | `beforeSubmitPrompt` | Before the user's prompt reaches the model |
| Context | `preCompact` | Before context compaction |
| Agent output | `afterAgentResponse`, `afterAgentThought` | Observe responses/thoughts |
| Completion | `stop`, `subagentStop` | May return `followup_message`; `loop_limit` applies |
| Subagents | `subagentStart`, `subagentStop` | |

Unknown event names are silently dead config — cursor-dev's validator warns
(`cursor-hook-unknown-event`); the most common cause is PascalCase names
ported from Claude Code.

**Cloud agents** run only a **command-type subset** of these events. Do not
make prompt hooks (or events outside the subset) load-bearing for workflows
that also run as cloud agents.

## Protocol

- **Input:** event payload as JSON on **stdin** (tool name, input, file path,
  etc. depending on event).
- **Output:** JSON on **stdout**.
- **Exit codes:** `0` = success (output consumed); `2` = **deny**; any other
  non-zero = error, **fail-open** by default (`failClosed: true` flips this).

Output fields by capability:

| Field | Returned by | Effect |
|---|---|---|
| `permission`: `"allow"` \| `"deny"` \| `"ask"` | blocking hooks (`preToolUse`, `beforeShellExecution`, `beforeMCPExecution`, `beforeReadFile`, …) | Gate the action; `"ask"` surfaces a user prompt. **Not** `permissionDecision` — that's Claude Code's key |
| `user_message` / `agent_message` | blocking hooks | Explanation shown to the user / injected for the agent |
| `updated_input` | `preToolUse` | Replace the tool's input (e.g. rewrite a command) |
| `additional_context` | `postToolUse` | Append context after the tool result |
| `followup_message` | `stop`, `subagentStop` | Send the agent back to work with this message (bounded by `loop_limit`) |
| `pluginPaths` | `workspaceOpen` | Inject plugin directories |

### Example: deny dangerous shell commands

```bash
#!/usr/bin/env bash
# .cursor/hooks/shell-guard.sh — beforeShellExecution
payload=$(cat)
cmd=$(printf '%s' "$payload" | jq -r '.command // empty')
if printf '%s' "$cmd" | grep -Eq 'rm -rf /|mkfs|dd if='; then
  jq -n '{permission:"deny", user_message:"Blocked: destructive command", agent_message:"That command is blocked by policy; propose a safer alternative."}'
  exit 0
fi
jq -n '{permission:"allow"}'
```

## Differences from Claude Code hooks (do not port blindly)

1. **camelCase** event names, not PascalCase.
2. Top-level **`version`** integer is required.
3. Decision key is **`permission`**, not `permissionDecision`.
4. Extra event families Claude Code lacks: Tab events, MCP-execution pair,
   `beforeReadFile`, `workspaceOpen`.
5. Stop-loop protection is the built-in `loop_limit` (default 5), not a
   manual `stop_hook_active` guard.
6. **Prompt-type hooks** (LLM-evaluated conditions) have no Claude Code
   equivalent.

Source: [cursor.com/docs/hooks.md](https://cursor.com/docs/hooks.md).
Verified 2026-06-09.
