# Hermes MCP wiring: mcp_servers, auth, CLI, hermes mcp serve

Facts verified 2026-06-09 against hermes-agent.nousresearch.com/docs and
github.com/NousResearch/hermes-agent, Hermes Agent v0.16.0 "The Surface
Release" (June 5, 2026). Hermes ships multiple minor releases per month —
re-verify before shipping.

## config.yaml: mcp_servers

Every entry must have **either `command` (stdio) or `url` (HTTP)** — the
deterministic validator errors with `hermes-config-mcp` on entries with
neither.

### stdio (local process)

```yaml
mcp_servers:
  docs:
    command: npx
    args: ["-y", "@example/docs-mcp"]
    env:
      DOCS_ROOT: /srv/docs
```

### HTTP (remote)

```yaml
mcp_servers:
  search:
    url: https://mcp.example.com/sse
    headers:
      X-Team: research
```

### Auth

| Mechanism | Keys |
|---|---|
| Static headers | `headers:` (e.g. bearer tokens — prefer env interpolation over literals) |
| OAuth 2.1 | `auth: oauth` — Hermes runs the OAuth 2.1 flow and persists tokens |
| mTLS | `client_cert:` + `client_key:` paths |

```yaml
mcp_servers:
  corp:
    url: https://mcp.corp.example/api
    auth: oauth
  internal:
    url: https://mcp.internal.example
    client_cert: ~/.hermes/certs/client.pem
    client_key: ~/.hermes/certs/client.key
```

## CLI and runtime

| Command | Does |
|---|---|
| `hermes mcp` | browse the curated MCP server catalog |
| `hermes mcp install <name>` | install a catalog server and write its config |
| `hermes mcp configure <name>` | (re)wire an entry interactively |
| `/reload-mcp` | hot-reload server config inside a session |
| `hermes mcp serve` | run **Hermes itself as an MCP server** — exposes Hermes's tools/agent to any MCP client (Claude Code, Cursor, another Hermes) |

`hermes mcp serve` is the composition trick: a heavier orchestrator can drive
Hermes as a tool, or two Hermes instances can call each other.

## Checklist for shipping an MCP config

- Each entry has `command` or `url` (validator: `hermes-config-mcp`).
- config.yaml parses as YAML (validator: `hermes-config-parse`).
- No literal secrets in `headers:` — use env interpolation or `auth: oauth`.
- stdio servers' `command` exists on PATH for the target machine.
- After edits in a live session, `/reload-mcp` (no restart needed).

Verified 2026-06-09 — hermes-agent.nousresearch.com/docs (mcp),
github.com/NousResearch/hermes-agent, v0.16.0.
