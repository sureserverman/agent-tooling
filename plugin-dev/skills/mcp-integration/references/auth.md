# MCP Auth Patterns

How to handle secrets, tokens, and OAuth for MCP servers inside Claude Code plugins.

## Contents

1. [Core rule — never hardcode](#core-rule)
2. [stdio: env vars](#stdio-env-vars)
3. [Remote: bearer tokens](#remote-bearer-tokens)
4. [Remote: OAuth](#remote-oauth)
5. [Decision table](#decision-table)
6. [Anti-patterns](#anti-patterns)

---

## Core rule

`.mcp.json` is a committed file. Any secret written literally into it will end up in version history. Use shell variable expansion for every credential:

```json
"env": {
  "API_KEY": "${MY_SERVICE_API_KEY}"
}
```

Claude Code expands `${}` references from the shell environment before launching the server. The user sets the variable in their shell profile or a `.env` file that is `.gitignore`d.

---

## stdio: env vars

The simplest and most common pattern for plugin-bundled (`stdio`) servers.

### How it works

1. `.mcp.json` declares the variable name with a `${}` placeholder.
2. The user exports the variable in their shell (`.bashrc`, `.zshrc`, or a sourced `.env`).
3. Claude Code passes the expanded value to the server subprocess via its environment.
4. The server reads it from `process.env` (Node), `os.environ` (Python), or `std::env::var` (Rust/Go).

### Example

`.mcp.json`:

```json
{
  "mcpServers": {
    "my-db": {
      "type": "stdio",
      "command": "node",
      "args": ["${CLAUDE_PLUGIN_ROOT}/server/index.js"],
      "env": {
        "DATABASE_URL": "${MY_PLUGIN_DB_URL}",
        "API_SECRET":  "${MY_PLUGIN_API_SECRET}"
      }
    }
  }
}
```

User's `.env` (git-ignored):

```sh
export MY_PLUGIN_DB_URL="postgres://user:pass@localhost/mydb"
export MY_PLUGIN_API_SECRET="sk-..."
```

Document the required env vars in your plugin README so the user knows what to set.

### Multiple credentials

Group all credentials under a plugin-specific prefix to avoid collisions with other plugins:

```
MY_PLUGIN_API_KEY
MY_PLUGIN_DB_URL
MY_PLUGIN_WEBHOOK_SECRET
```

---

## Remote: bearer tokens

Use for `sse`, `http`, or `ws` servers that accept a static API token.

### Pattern

`.mcp.json`:

```json
{
  "mcpServers": {
    "remote-service": {
      "type": "http",
      "url": "https://api.example.com/mcp",
      "env": {
        "BEARER_TOKEN": "${EXAMPLE_BEARER_TOKEN}"
      }
    }
  }
}
```

The remote MCP server is responsible for reading `BEARER_TOKEN` from its own environment (if it's a server you control) or for injecting it into outbound request headers.

**Note:** Claude Code does not automatically inject an `Authorization: Bearer ...` header from the `env` block for remote transports. If you control the remote server, read the token from the request context. If you don't, use a local proxy sidecar (see below).

### Local proxy sidecar pattern

> **Inferred pattern, not first-class.** This sidecar approach is composed from how `stdio` and remote transports work together. It is not documented as a Claude Code feature in its own right. Verify behavior against `code.claude.com/docs/en/plugins-reference` before relying on it for production.

When you need to inject auth headers into a third-party remote server, ship a thin local proxy as `stdio` and have it forward to the real remote:

```
Claude Code → stdio → local-proxy (adds Authorization header) → https://api.example.com/mcp
```

`.mcp.json`:

```json
{
  "mcpServers": {
    "proxied-service": {
      "type": "stdio",
      "command": "node",
      "args": ["${CLAUDE_PLUGIN_ROOT}/proxy/index.js"],
      "env": {
        "UPSTREAM_URL":   "https://api.example.com/mcp",
        "BEARER_TOKEN":   "${EXAMPLE_BEARER_TOKEN}"
      }
    }
  }
}
```

The proxy reads `BEARER_TOKEN` from env, forwards all MCP calls to `UPSTREAM_URL` with `Authorization: Bearer ${BEARER_TOKEN}`, and relays responses back over stdio.

---

## Remote: OAuth

Use when the service requires user-delegated OAuth (e.g., GitHub, Google, Jira with OAuth apps).

### How Claude Code handles OAuth

Claude Code's plugin framework supports an OAuth consent flow when `oauth` is configured in the plugin manifest. The framework:

1. Detects the server requires OAuth on first tool call.
2. Opens the authorization URL in the user's browser.
3. Handles the redirect and stores the token in the plugin's credential store (not in `.mcp.json`).
4. Refreshes tokens automatically.

### Plugin manifest snippet

> **Illustrative — verify field name.** The `mcpAuth` key shown below is a representative shape, not a verbatim quote of the current schema. Confirm the exact field name (`mcpAuth`, `oauth`, or otherwise) and the property names against `code.claude.com/docs/en/plugins-reference` before shipping a plugin that depends on it.

In `.claude-plugin/manifest.json`:

```json
{
  "mcpAuth": {
    "my-service": {
      "type": "oauth2",
      "authorizationUrl": "https://example.com/oauth/authorize",
      "tokenUrl":         "https://example.com/oauth/token",
      "scopes":           ["read", "write"],
      "clientId":         "${MY_SERVICE_OAUTH_CLIENT_ID}"
    }
  }
}
```

`clientId` uses variable expansion. The client secret is never stored in committed files — the plugin framework prompts for it on first activation or reads it from the credential store.

### When OAuth is overkill

Use OAuth when the service requires it or the token represents a user identity. Use a bearer token when you control the service, issue static tokens, or the integration is single-user.

---

## Decision table

| Scenario | Auth pattern |
|---|---|
| Bundled stdio server, secrets are static | `env:` block with `${}` expansion |
| Remote service with static API key | `env: { BEARER_TOKEN: "${...}" }` + proxy if header injection needed |
| Remote service requiring user identity | OAuth via plugin manifest `mcpAuth` |
| Remote service, you control the server | Server reads token from its own env; client sends token in `env:` block |
| Multiple credentials, same plugin | Prefix all env var names with `PLUGIN_NAME_` |

---

## Anti-patterns

| Anti-pattern | Risk |
|---|---|
| Literal secret in `.mcp.json` | Secret committed to repo; credential leak |
| Token stored in `.claude-plugin/` config files | May be committed; check `.gitignore` first |
| OAuth client secret in committed file | Keep in credential store only; treat like a password |
| Logging env vars in server output | Secrets appear in Claude Code's debug log |

---

## Troubleshooting

| Symptom | Likely cause | Check |
|---|---|---|
| `401 Unauthorized` | token missing or not expanded | Is the `${VAR}` actually set in the shell that launched Claude Code? `echo $VAR` in that shell. |
| `403 Forbidden` | token valid but lacks scope | Re-issue the token / OAuth grant with the required scopes; document them in the README. |
| "token not found" at startup | env var unset or named differently | Confirm the `.mcp.json` key matches the exported var name exactly (prefix included). |
| Works once, then fails | short-lived/expiring token | Don't bake it into `env:` — use the local proxy sidecar to fetch/refresh per request. |
| OAuth loop (re-prompts every call) | token store not persisting | Verify the credential store is writable; re-run the consent flow once. |

For static debugging, hit the remote directly with `curl -H "Authorization: Bearer $VAR" <url>` to isolate whether the problem is the token or the MCP wiring.

**Dynamic / expiring tokens:** when a credential must be minted per request (HMAC signatures, short TTLs, time-based auth), the `env:` block can't help — it's evaluated once at launch. Use the local proxy sidecar (above): the proxy mints the header on each call and forwards over stdio.
