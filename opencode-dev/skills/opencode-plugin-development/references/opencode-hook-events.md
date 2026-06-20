# OpenCode hook events (verified 2026-06-09, OpenCode v1.16)

The hook names a plugin can return handlers for. Grouped by lifecycle; names
are exact strings (dot-separated, lowercase). Unknown names are silently
ignored — typos never error.

## Tool execution

| Hook | Fires |
|---|---|
| `tool.execute.before` | before any tool runs; receives `(input, output)` where `input.tool` is the tool name and `output.args` the arguments — **throw to block** |
| `tool.execute.after` | after a tool completes; inspect/transform results |

## Shell & commands

| Hook | Fires |
|---|---|
| `shell.env` | when OpenCode builds the shell environment — mutate env vars for spawned shells |
| `command.executed` | after a `/command` runs |

## Files

| Hook | Fires |
|---|---|
| `file.edited` | after OpenCode edits a file |
| `file.watcher.updated` | when the file watcher sees an external change |

## Permissions

| Hook | Fires |
|---|---|
| `permission.asked` | when a permission prompt is raised — auto-answer policy lives here |
| `permission.replied` | after the user (or a hook) answers |

## Messages

| Hook | Fires |
|---|---|
| `message.updated` | message created/updated in a session |
| `message.removed` | message deleted |
| `message.part.updated` | a part (text/tool-call chunk) updated — fine-grained streaming |
| `message.part.removed` | a part removed |

## Sessions

| Hook | Fires |
|---|---|
| `session.created` | new session |
| `session.updated` | session metadata changed |
| `session.deleted` | session removed |
| `session.idle` | the agent finished and is waiting — the classic "notify me" hook |
| `session.error` | a session-level error |
| `session.status` | status transitions |
| `session.diff` | the session's workspace diff changed |
| `session.compacted` | context compaction completed |
| `experimental.session.compacting` | during compaction (experimental — name may change; gate on version) |

## Todo, LSP, infra

| Hook | Fires |
|---|---|
| `todo.updated` | the agent's todo list changed |
| `lsp.updated` | LSP server state changed |
| `lsp.client.diagnostics` | diagnostics arrived from an LSP server |
| `installation.updated` | OpenCode itself updated |
| `server.connected` | a client connected to the server |

## TUI

| Hook | Fires |
|---|---|
| `tui.prompt.append` | append text to the user's prompt box |
| `tui.command.execute` | execute a TUI command programmatically |
| `tui.toast.show` | show a toast notification |

## Reliability note — the v1.15 Effect rebuild

**v1.15.0 (May 2026) rebuilt event delivery on an Effect-based core.**
Pre-1.15, delivery was best-effort: events could drop or arrive out of order,
and several community tutorials taught defensive patterns (polling fallbacks,
idempotent replay guards) to compensate. Post-1.15 delivery is reliable and
ordered. When reading any plugin tutorial, check its date: **pre-May-2026
material describes a different runtime.**

Practical rules:

- Don't add polling fallbacks "just in case" — dead weight post-1.15.
- `experimental.*` hooks are unstable by contract; feature-detect or pin.
- Hook names are silently ignored when unknown — after an upgrade, re-verify
  names against this table (and this table against the docs).

Source: [opencode.ai/docs/plugins](https://opencode.ai/docs/plugins);
v1.15.0 release notes at
[github.com/anomalyco/opencode](https://github.com/anomalyco/opencode).
Verified 2026-06-09.
