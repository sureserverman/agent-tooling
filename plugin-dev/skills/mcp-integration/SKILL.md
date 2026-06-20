---
name: mcp-integration
description: Use when wiring an MCP server into a Claude Code plugin. Triggers on ".mcp.json", "stdio MCP", "SSE MCP", "${CLAUDE_PLUGIN_ROOT} with MCP", "MCP auth".
---

# mcp-integration

Decision rules for shipping an MCP server inside a Claude Code plugin — when to reach for MCP, how to configure `.mcp.json`, which transport to use, and how to handle auth.

> **Authoring vs integrating.** This skill covers wiring an MCP server into a plugin. For *building* a custom MCP server (tool design, JSON-RPC errors, security, testing with the Inspector), use the sibling `mcp-server-development` skill.

## Reference map

| When you're… | Read first |
|---|---|
| Choosing between `stdio`, `sse`, `http`, or `ws` | `references/server-types.md` |
| Handling secrets, OAuth, or bearer tokens | `references/auth.md` |
| Designing the server itself (tools, schemas, errors) | `mcp-server-development` skill |

---

## 1. Skill vs MCP — pick the right tool

**Use a skill when** the work is pure decision rules, codified workflow, or domain knowledge that Claude can execute with existing tools (Bash, Read, Write, Edit). No external state, no cross-process boundary.

**Use an MCP server when** Claude needs to reach across a process boundary to:
- Query or mutate a database
- Call a remote API with persistent state
- Index a local file tree and serve semantic search
- Drive a browser or external process

If a skill + the Bash tool can do the job in one hop, don't add an MCP server. MCP is overhead — a subprocess, a protocol, a new failure surface.

---

## 2. `.mcp.json` — location and shape

Place `.mcp.json` at the **plugin root** (the directory that contains `.claude-plugin/`). Do not put it inside `.claude-plugin/`.

```
my-plugin/
  .claude-plugin/
    ...
  .mcp.json        ← correct location
  server/
    index.js
```

MCP servers are **not auto-discovered**. The user must activate the plugin to opt in. Document the activation step in your plugin's README.

### Schema

```json
{
  "mcpServers": {
    "<server-name>": {
      "type": "stdio",
      "command": "${CLAUDE_PLUGIN_ROOT}/server/index.js",
      "args": ["--port", "0"],
      "env": {
        "API_KEY": "${MY_SERVICE_API_KEY}"
      }
    }
  }
}
```

| Field | Required | Notes |
|---|---|---|
| `type` | yes | `stdio` \| `sse` \| `http` \| `ws` |
| `command` | yes for stdio | Use `${CLAUDE_PLUGIN_ROOT}` — never an absolute path |
| `args` | no | Array of strings |
| `env` | no | String-to-string map; use shell variable expansion for secrets |
| `url` | yes for sse/http/ws | Base URL of the remote server |

---

## 3. Transport at a glance

| Type | When to use |
|---|---|
| `stdio` | Bundled local server. Most common for plugin-shipped MCPs. |
| `sse` | Long-lived remote server with streaming results. |
| `http` | Simple remote service, no streaming required. |
| `ws` | Bidirectional remote streaming. |

Full worked examples and trade-off matrix: `references/server-types.md`.

---

## 4. Auth — quick rules

- **stdio bundled**: pass secrets via `env:` block using shell variable expansion (`${MY_SECRET}`). Never hardcode values.
- **Remote (sse/http/ws)**: use Claude Code's OAuth flow when the service supports it, or a bearer token in `env:`.
- `.mcp.json` gets committed. **Never hardcode a secret in it.**

Full patterns and per-transport guidance: `references/auth.md`.

---

## 5. Anti-patterns

| Anti-pattern | Why it fails |
|---|---|
| `.mcp.json` inside `.claude-plugin/` | Framework never finds it — wrong location |
| Hardcoded absolute paths in `command` / `args` | Breaks on every machine but the author's |
| Hardcoded secrets in `.mcp.json` | Committed to the repo; credential leak |
| Bundling >100 MB of Node deps in the plugin | Bloats plugin install; use a published binary or external install instructions |
| Exposing destructive tools without user-approval gates | MCP tools can be auto-called; gate them behind explicit user confirmation |
| Reaching for MCP when Bash + a skill suffices | Unnecessary subprocess, protocol, and failure surface |

---

## Sources

- https://modelcontextprotocol.io
- https://code.claude.com/docs/en/mcp
- https://code.claude.com/docs/en/plugins-reference
