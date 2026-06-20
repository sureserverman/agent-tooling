# OpenCode MCP servers and themes (verified 2026-06-09, OpenCode v1.16)

## MCP servers — the `mcp` config key

Two shapes, keyed by server name:

### Local (stdio subprocess)

```json
{
  "mcp": {
    "my-db": {
      "type": "local",
      "command": ["bunx", "my-mcp-server", "--stdio"],
      "environment": { "DB_URL": "{env:DB_URL}" },
      "enabled": true,
      "timeout": 5000
    }
  }
}
```

- `command` is an **array** (argv), not a shell string.
- `environment` — extra env vars for the subprocess; use `{env:}`/`{file:}`
  substitution, never literal secrets.
- `timeout` — tool-call timeout in ms, **default 5000**; raise it for slow
  servers before blaming the server.

### Remote (HTTP/SSE)

```json
{
  "mcp": {
    "linear": {
      "type": "remote",
      "url": "https://mcp.linear.app/sse",
      "headers": { "Authorization": "Bearer {env:LINEAR_TOKEN}" },
      "enabled": true,
      "timeout": 5000
    }
  }
}
```

### OAuth

For remote servers, OAuth is **automatic**: on a 401, OpenCode runs the OAuth
flow, including **Dynamic Client Registration (RFC 7591)** — most compliant
servers need zero auth config. Overrides:

- Pre-registered client: `"oauth": {"clientId": "...", "clientSecret": "...", "scope": "..."}`
- Disable entirely: `"oauth": false` (e.g. when auth is via `headers`)

### The context-bloat gotcha (doc-flagged)

**Every enabled MCP server's tool definitions are sent with your messages and
consume context.** The official docs flag this; GitHub's MCP server is the
notorious offender (dozens of verbose tool schemas on every turn). The
pattern:

1. Define the server in config with `"enabled": false`.
2. Re-enable it **per agent** that actually needs it (agent-level
   tools/permission config can switch MCP tools on for that agent only).

Result: the main loop stays lean; the specialist agent pays the tax only when
dispatched.

### MCP vs custom tool

Repo-local logic → custom tool (`.opencode/tools/`, no server process, no
schema tax). External service with an existing MCP surface → MCP. See
`opencode-plugin-development` → `opencode-custom-tools.md`.

## Themes

### Locations

| Scope | Path |
|---|---|
| Global | `~/.config/opencode/themes/<name>.json` |
| Project | `.opencode/themes/<name>.json` |

Plural `themes/` canonical (singular legacy — `opencode-singular-dir`).
Select with the `/theme` picker in the TUI, or set the theme in `tui.json`.

### Format

```json
{
  "$schema": "https://opencode.ai/theme.json",
  "defs": {
    "bg": "#1e1e2e",
    "accent": "#89b4fa"
  },
  "theme": {
    "primary": "accent",
    "background": { "dark": "bg", "light": "#eff1f5" },
    "borderSubtle": 240,
    "diffAdded": "#a6e3a1",
    "diffRemoved": "none"
  }
}
```

- `defs` — named color definitions you reference from `theme`.
- `theme` — the actual slot→color map. Values may be:
  - hex (`"#89b4fa"`)
  - ANSI 0–255 (a bare number — adapts to the terminal palette)
  - a reference to a `defs` name
  - a `{"dark": ..., "light": ...}` pair (per terminal background)
  - `"none"` (no color / terminal default)

### Built-ins

`opencode` (default), `system` (derives from terminal colors), plus ports of
the usual suspects: `tokyonight`, `catppuccin`, `gruvbox`, and others — run
`/theme` to list what your version ships. Start a custom theme by copying the
built-in closest to your target.

## Checklist

1. `mcp.command` is an argv array; secrets via `{env:}`/`{file:}`.
2. Fat MCP servers disabled globally, enabled per agent.
3. OAuth: try zero-config first (automatic + DCR); only add `oauth` keys when
   the server demands pre-registration.
4. Themes in plural `themes/`; every color a valid hex/ANSI/ref/pair/none.
5. Run opencode-dev's `scripts/validate.sh` over the artifact
   (`opencode-config-parse`, `opencode-config-unknown-key`,
   `opencode-singular-dir`).

Source: [opencode.ai/docs/mcp-servers](https://opencode.ai/docs/mcp-servers);
[opencode.ai/docs/themes](https://opencode.ai/docs/themes).
Verified 2026-06-09.
