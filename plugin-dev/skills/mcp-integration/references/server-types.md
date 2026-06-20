# MCP Server Types

Transport options for MCP servers bundled in or referenced by a Claude Code plugin.

## Contents

1. [stdio — bundled local server](#stdio)
2. [sse — remote streaming](#sse)
3. [http — simple remote](#http)
4. [ws — bidirectional remote](#ws)
5. [Trade-off matrix](#trade-off-matrix)

---

## stdio

**Transport:** Claude Code spawns the server as a child process and communicates over stdin/stdout pipes.

**When to use:** The server ships inside the plugin (Node script, Python script, compiled binary). This is the default choice for plugin-bundled MCPs.

### Worked example

Plugin layout:

```
my-plugin/
  .mcp.json
  server/
    index.js       ← the MCP server entry point
    package.json   ← must list all deps; no npm install at runtime
```

`.mcp.json`:

```json
{
  "mcpServers": {
    "my-service": {
      "type": "stdio",
      "command": "node",
      "args": ["${CLAUDE_PLUGIN_ROOT}/server/index.js"],
      "env": {
        "DATABASE_URL": "${MY_PLUGIN_DATABASE_URL}"
      }
    }
  }
}
```

`server/index.js` (minimal skeleton):

```js
import { Server } from "@modelcontextprotocol/sdk/server/index.js";
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";

const server = new Server({ name: "my-service", version: "1.0.0" }, {
  capabilities: { tools: {} }
});

server.setRequestHandler("tools/list", async () => ({
  tools: [{
    name: "query_db",
    description: "Query the project database",
    inputSchema: {
      type: "object",
      properties: { sql: { type: "string" } },
      required: ["sql"]
    }
  }]
}));

server.setRequestHandler("tools/call", async (req) => {
  const { name, arguments: args } = req.params;
  if (name === "query_db") {
    // ... run the query
    return { content: [{ type: "text", text: JSON.stringify(result) }] };
  }
  throw new Error(`Unknown tool: ${name}`);
});

const transport = new StdioServerTransport();
await server.connect(transport);
```

**Gotchas:**
- `node_modules` must be present at `${CLAUDE_PLUGIN_ROOT}/server/node_modules`. There is no install step at runtime; ship deps or use a compiled binary.
- Keep the dep tree small. Over ~100 MB triggers plugin-size warnings; prefer a pre-compiled binary (Go or Rust) for heavy workloads.
- stdout is the protocol channel. Never `console.log` to stdout — use `console.error` or a log file.

---

## sse

**Transport:** Server-Sent Events over HTTP. Claude Code connects to a long-lived remote HTTP server and reads a stream of events.

**When to use:** A remote service you do not control, or a service that streams incremental results (logs, progress, search hits).

### Worked example

`.mcp.json`:

```json
{
  "mcpServers": {
    "remote-search": {
      "type": "sse",
      "url": "https://search.example.com/mcp/sse",
      "env": {
        "BEARER_TOKEN": "${SEARCH_BEARER_TOKEN}"
      }
    }
  }
}
```

The remote server exposes an SSE endpoint at the configured URL. Claude Code sends JSON-RPC requests as HTTP POST to the same base URL and receives streamed responses on the SSE channel.

**Gotchas:**
- The SSE connection is long-lived; ensure the remote server handles reconnects gracefully.
- Firewalls that terminate idle connections will break the stream. Use a keep-alive ping or SSE heartbeat (`: ping` comment line every 15–30 s).
- Auth header injection: Claude Code does not automatically inject `Authorization` headers from `env`. The server must read the token from env and enforce it server-side, or you must configure a proxy.

---

## http

**Transport:** Plain HTTP / JSON-RPC 2.0. Stateless request/response, no streaming.

**When to use:** Simple remote service where streaming is not needed and the round-trip latency is acceptable (< ~2 s per call).

### Worked example

`.mcp.json`:

```json
{
  "mcpServers": {
    "jira": {
      "type": "http",
      "url": "https://mcp.example.com/jira",
      "env": {
        "JIRA_API_TOKEN": "${JIRA_API_TOKEN}"
      }
    }
  }
}
```

Claude Code sends `POST /jira` with a JSON-RPC body; the server responds synchronously.

**Gotchas:**
- No streaming — if a tool call takes > ~30 s, Claude Code may time out. Break long operations into a start/poll pattern.
- The `url` must be HTTPS in production. HTTP is accepted for `localhost` only.

---

## ws

**Transport:** WebSocket. Bidirectional, full-duplex streaming.

**When to use:** Remote services that need server-initiated pushes (real-time events, subscriptions) or very low-latency bidirectional messaging.

### Worked example

`.mcp.json`:

```json
{
  "mcpServers": {
    "live-data": {
      "type": "ws",
      "url": "wss://live.example.com/mcp/ws",
      "env": {
        "WS_SECRET": "${LIVE_DATA_SECRET}"
      }
    }
  }
}
```

**Gotchas:**
- WebSocket connections are stateful. Reconnect logic must live on the server side (Claude Code reconnects on disconnect, but does not buffer in-flight messages).
- Corporate proxies often strip WebSocket upgrade headers. Test on the target network; `http` or `sse` may be more firewall-friendly.
- `wss://` (TLS) is required in production. `ws://` works on `localhost` only.

---

## Trade-off matrix

| | `stdio` | `sse` | `http` | `ws` |
|---|---|---|---|---|
| Location | Bundled local | Remote | Remote | Remote |
| Streaming | No | Yes (server → client) | No | Yes (bidirectional) |
| Setup complexity | Low | Medium | Low | High |
| Firewall friendliness | N/A (local) | Medium | High | Low |
| Best for | Plugin-shipped tools | Remote streaming results | Simple API calls | Real-time subscriptions |
| Dep size risk | Yes (bundle deps) | No | No | No |
| Auth surface | env vars | Bearer / OAuth | Bearer / OAuth | Bearer / OAuth |

**Default pick:** `stdio` for anything you ship inside the plugin. Only go remote (`sse`, `http`, `ws`) when the service cannot run locally.
