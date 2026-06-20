---
name: cursor-hooks-and-agents
description: Use when writing Cursor hooks, subagents, or MCP configuration. Triggers on "Cursor hook", "hooks.json for Cursor", "beforeShellExecution", "preToolUse in Cursor", "Cursor subagent", "Cursor agents folder", ".cursor/agents", "Cursor MCP config", ".cursor/mcp.json", "MCP install deeplink".
---

# cursor-hooks-and-agents

Three runtime extension surfaces of Cursor (the AI editor): **hooks** (lifecycle interceptors in `hooks.json`), **subagents** (markdown agents in `.cursor/agents/`), and **MCP** (`.cursor/mcp.json`). All three look deceptively like their Claude Code counterparts and all three differ in load-bearing ways — Cursor hooks use **camelCase** events and a `version` field, Cursor subagents have **no `tools` field**, and Cursor MCP has its own interpolation and OAuth machinery.

All facts verified 2026-06-09 against cursor.com/docs/hooks.md, /docs/subagents, and /docs/mcp.md (Cursor 3.7).

## Reference map

| When you need… | Read first |
|---|---|
| hooks.json schema, all four config locations + priority, the ~22 events, stdin/stdout protocol, exit codes, permission/`updated_input`/`followup_message` payloads, prompt-type hooks, Claude Code differences | `references/cursor-hooks.md` |
| Subagent frontmatter (model/readonly/is_background), discovery + `.claude`/`.codex` compat, built-ins (Explore, Bash, Browser), delegation behavior | `references/cursor-subagents.md` |
| mcp.json schema, transports, OAuth, `${env:NAME}`-style interpolation, `envFile`, MCP Apps, permissions.json, install deeplinks | `references/cursor-mcp.md` |

## Decision rules

### Hook, rule, or skill?

- **Deterministic enforcement** (block a command, redact a file read, append context after an edit) → **hook**. Rules and skills are advisory — the model can ignore them; hooks cannot be ignored.
- **Advisory constraint** → rule. **Capability** → skill (see `cursor-rules-and-skills`).
- **Natural-language condition** ("block anything that looks like it touches prod") → **prompt-type hook** — Cursor evaluates the condition with an LLM; `$ARGUMENTS` carries the event payload into the prompt. Command hooks for decidable conditions, prompt hooks for judgment calls.

### Where does the hooks.json go?

Four locations, highest priority first (full table in `cursor-hooks.md`):

1. **Enterprise MDM** — `/Library/Application Support/Cursor/hooks.json` (macOS), `/etc/cursor/hooks.json` (Linux), `C:\ProgramData\Cursor\hooks.json` (Windows)
2. **Team** — dashboard-managed
3. **Project** — `.cursor/hooks.json`
4. **User** — `~/.cursor/hooks.json`

Schema skeleton — note the **integer `version`** and **camelCase** event names:

```json
{
  "version": 1,
  "hooks": {
    "beforeShellExecution": [
      { "command": "./hooks/guard.sh", "type": "command", "timeout": 30 }
    ]
  }
}
```

Per-hook keys: `command`, `type` (`"command"` | `"prompt"`), `timeout`, `loop_limit` (default 5; applies to `stop`/`subagentStop` — the built-in guard against infinite stop loops), `failClosed`, `matcher`.

### This is NOT Claude Code's hooks format

Porting a Claude Code hooks.json verbatim fails silently. The differences:

| | Cursor | Claude Code |
|---|---|---|
| Event case | camelCase (`preToolUse`) | PascalCase (`PreToolUse`) |
| Top-level `version` | required integer | absent |
| Permission key | `permission`: `"allow"`/`"deny"`/`"ask"` | `permissionDecision` |
| Extra event families | Tab events, MCP-execution events, `beforeReadFile`, `workspaceOpen` | — |
| Stop-loop guard | built-in `loop_limit` | manual `stop_hook_active` check |

cursor-dev's deterministic lane errors on missing/non-integer `version` and warns on unknown (e.g. PascalCase) event names (`cursor-hook-unknown-event`).

### Which event? (~22, camelCase)

Lifecycle: `sessionStart`, `sessionEnd`, `workspaceOpen` (can return `{"pluginPaths": [...]}` to inject plugins). Tools: `preToolUse`, `postToolUse`, `postToolUseFailure`. Shell: `beforeShellExecution`, `afterShellExecution`. MCP: `beforeMCPExecution`, `afterMCPExecution`. Files: `beforeReadFile`, `afterFileEdit`. Tab: `beforeTabFileRead`, `afterTabFileEdit`. Agent flow: `beforeSubmitPrompt`, `preCompact`, `afterAgentResponse`, `afterAgentThought`, `stop`, `subagentStart`, `subagentStop`. Full protocol per event in `cursor-hooks.md`. **Cloud agents run a command-type subset only** — don't make prompt hooks load-bearing for cloud runs.

Protocol in one line: JSON on stdin, JSON on stdout; exit 0 = ok, exit 2 = deny, anything else = fail-open (unless `failClosed`). Blocking hooks return `permission: "allow"|"deny"|"ask"` with `user_message`/`agent_message`; `preToolUse` may return `updated_input`; `postToolUse` may return `additional_context`; `stop`/`subagentStop` may return `followup_message`.

### Subagent or main agent?

Ship a subagent when a task benefits from **isolation** (own context window), **parallelism**, or a **restricted posture** (`readonly: true`). Files in `.cursor/agents/` (project) or `~/.cursor/agents/` (user); Cursor also compat-reads `.claude/agents/`, `.codex/agents/` and their home equivalents — **project wins** over home on name collision.

Frontmatter: `name` (optional — defaults to filename), `description` (the routing signal; phrase "use proactively" to nudge auto-delegation), `model` (inherit default or pin an id), `readonly`, `is_background`. **There is no `tools` field** — unlike Claude Code, you cannot whitelist tools per agent; `readonly: true` is the only restriction lever. Built-ins already cover exploration (`Explore`), shell (`Bash`), and web (`Browser`) — don't ship a subagent that duplicates one. Details in `cursor-subagents.md`.

### MCP: project or user scope, and how do users approve it?

`.cursor/mcp.json` (project) or `~/.cursor/mcp.json` (user). Transports: **stdio** (local `command`), **Streamable HTTP** (remote, current), **SSE** (legacy). Remote servers get **OAuth auto-discovery** with callback `cursor://anysphere.cursor-mcp/oauth/callback`. Config interpolation: `${env:NAME}`, `${userHome}`, `${workspaceFolder}`, `${workspaceFolderBasename}`, `${/}`; plus `envFile` for secrets. Since 3.6, a project `permissions.json` can relax per-server approval prompts; since 2.6, **MCP Apps** let servers render interactive UI. One-click distribution: the install deeplink `cursor://anysphere.cursor-deeplink/mcp/install?name=$NAME&config=$BASE64`. All schemas and a worked deeplink example in `cursor-mcp.md`.

## Anti-patterns this skill catches

- PascalCase event names (`PreToolUse`) in a Cursor hooks.json — that's Claude Code's casing; the hook never fires (`cursor-hook-unknown-event`).
- hooks.json without integer `version` — schema violation (`cursor-hooks-version`).
- Returning `permissionDecision` from a Cursor hook — Cursor reads `permission`.
- A `tools:` list in a Cursor subagent's frontmatter — silently meaningless; use `readonly: true`.
- A `stop` hook relying on a hand-rolled loop guard — set `loop_limit` instead (and know it defaults to 5).
- Prompt-type hooks as the only enforcement for cloud agent runs — cloud agents execute a command-type subset only.
- Hardcoded secrets in mcp.json — use `${env:NAME}` or `envFile`.
- Absolute machine-specific paths in project mcp.json — use `${workspaceFolder}`/`${userHome}`.

## Sources

- Cursor, *Hooks* — locations/priority, schema, events, protocol, prompt hooks, cloud subset ([cursor.com/docs/hooks.md](https://cursor.com/docs/hooks.md)). Verified 2026-06-09.
- Cursor, *Subagents* — discovery + compat dirs, frontmatter, built-ins, parallelism ([cursor.com/docs/subagents](https://cursor.com/docs/subagents)). Verified 2026-06-09.
- Cursor, *MCP* — mcp.json, transports, OAuth, interpolation, MCP Apps, permissions.json, deeplinks ([cursor.com/docs/mcp.md](https://cursor.com/docs/mcp.md)). Verified 2026-06-09.

When upstream behavior changes, update the references — not this SKILL.md.
