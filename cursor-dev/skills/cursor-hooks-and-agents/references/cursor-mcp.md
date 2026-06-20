# Cursor MCP — mcp.json, transports, OAuth, interpolation, deeplinks (verified 2026-06-09, Cursor 3.7)

MCP wires external tool servers into Cursor's agent. Config lives in
`mcp.json`; remote servers get OAuth automatically; one-click installs ship as
deeplinks.

## Config locations

| Scope | Path |
|---|---|
| Project | `.cursor/mcp.json` |
| User | `~/.cursor/mcp.json` |

## Schema and transports

```json
{
  "mcpServers": {
    "local-tool": {
      "command": "npx",
      "args": ["-y", "my-mcp-server"],
      "env": { "API_KEY": "${env:MY_API_KEY}" },
      "envFile": "${workspaceFolder}/.env"
    },
    "remote-tool": {
      "url": "https://mcp.example.com/mcp"
    }
  }
}
```

| Transport | Config shape | Status |
|---|---|---|
| **stdio** | `command` (+ `args`, `env`, `envFile`) — Cursor spawns the process locally | current |
| **Streamable HTTP** | `url` | current, preferred for remote |
| **SSE** | `url` (SSE endpoint) | **legacy** — superseded by Streamable HTTP |

- `envFile` — load environment variables (secrets) from a dotenv file instead
  of inlining them.

## Interpolation

Usable inside `mcp.json` values:

| Variable | Expands to |
|---|---|
| `${env:NAME}` | Environment variable `NAME` |
| `${userHome}` | The user's home directory |
| `${workspaceFolder}` | Absolute path of the workspace root |
| `${workspaceFolderBasename}` | Workspace root directory name |
| `${/}` | Platform path separator |

Never hardcode secrets or machine-specific absolute paths in a committed
project `mcp.json` — use `${env:NAME}`/`envFile` and
`${workspaceFolder}`/`${userHome}`.

## OAuth (remote servers)

- **Auto-discovery**: when a remote server advertises OAuth, Cursor runs the
  flow automatically — no manual token plumbing in config.
- Redirect/callback URL: `cursor://anysphere.cursor-mcp/oauth/callback`
  (register this with the authorization server).

## Permissions and approvals

- **3.6+**: a project **`permissions.json`** plus the **Auto-review** feature
  can relax per-tool approval prompts — MCP tool calls that policy allows run
  without an interactive ask.
- Hook events `beforeMCPExecution` / `afterMCPExecution` wrap every MCP call
  for deterministic gating (see `cursor-hooks.md`).

## MCP Apps (2.6+)

Since Cursor 2.6, MCP servers can render **interactive UI** inside the editor
(MCP Apps), not just return text/tool results. Don't depend on it for users
below 2.6.

## Install deeplinks

One-click distribution:

```
cursor://anysphere.cursor-deeplink/mcp/install?name=$NAME&config=$BASE64_CONFIG
```

`name` is the server key; `config` is the **base64-encoded JSON** of the
server's config object (the value that would sit under `mcpServers.$NAME`).
Worked example:

```bash
NAME=remote-tool
CONFIG=$(printf '%s' '{"url":"https://mcp.example.com/mcp"}' | base64 -w0)
echo "cursor://anysphere.cursor-deeplink/mcp/install?name=$NAME&config=$CONFIG"
```

## Differences from Claude Code MCP (do not port blindly)

1. File name/location: `.cursor/mcp.json` + `~/.cursor/mcp.json` — not
   `.mcp.json` at the repo root.
2. Interpolation set is Cursor's (`${env:NAME}`, `${userHome}`,
   `${workspaceFolder}`, `${workspaceFolderBasename}`, `${/}`) — not
   `${CLAUDE_PLUGIN_ROOT}`.
3. OAuth callback is the `cursor://anysphere.cursor-mcp/oauth/callback`
   deeplink, handled by the editor.
4. Cursor adds `envFile`, MCP Apps (2.6+), `permissions.json` + Auto-review
   (3.6+), and install deeplinks.

Source: [cursor.com/docs/mcp.md](https://cursor.com/docs/mcp.md).
Verified 2026-06-09.
