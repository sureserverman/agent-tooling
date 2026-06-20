# SDK & Transport Choice

Which language, which SDK, which transport. For deciding `stdio` vs `sse` vs `http` vs `ws` from the *client* side, see `mcp-integration/references/server-types.md`. This file is about the *server* side trade-offs.

## Contents

1. [Pick a language](#language)
2. [TypeScript — `@modelcontextprotocol/sdk`](#typescript)
3. [Python — `mcp` / FastMCP](#python)
4. [Rust, Go, Ruby, others](#other-languages)
5. [Transport from the server side](#transport)
6. [Streamable HTTP — the modern remote default](#streamable-http)
7. [Distribution: source vs binary](#distribution)

---

## Language

| Language | Pick when | Mature SDK |
|---|---|---|
| **TypeScript / Node** | Default for plugin-bundled stdio servers; richest tool tooling; FastMCP-equivalent ergonomics | `@modelcontextprotocol/sdk` |
| **Python** | Server wraps a Python-only library (ML, scientific), or you want FastMCP's decorator API | `mcp` (FastMCP is the high-level layer) |
| **Rust** | Performance-critical or you want a single static binary; willing to write a touch more boilerplate | `mcp-server` / `rmcp` (community, evolving) |
| **Go** | Single binary, easy cross-compile, you already have a Go service to wrap | `mcp-go` (community) |
| **Ruby** | Wrapping a Rails app or Ruby-only service | `mcp` gem (official) |

Don't pick a language just because the SDK exists — the language has to match what the server *does*. If 80% of the server's work is calling Pandas, write it in Python.

---

## TypeScript

Install:

```sh
npm install @modelcontextprotocol/sdk zod
```

Key types:

- `McpServer` — high-level façade with `registerTool`, `registerResource`, `registerPrompt`. Use this.
- `Server` — low-level, raw JSON-RPC handler (`setRequestHandler("tools/list", …)`). Reach for this only when you need behavior `McpServer` doesn't expose.
- `StdioServerTransport` — for plugin-bundled servers.
- `StreamableHTTPServerTransport` — for remote (the modern HTTP+SSE replacement).

Pattern: define each tool with Zod schemas, let the SDK derive JSON Schema:

```ts
server.registerTool(
  "my_tool",
  {
    title: "My tool",
    description: "...",
    inputSchema: { x: z.number(), y: z.string().optional() },
  },
  async ({ x, y }) => ({ content: [{ type: "text", text: String(x) }] }),
);
```

**Gotchas:**
- Don't `console.log` — use `console.error` (stderr is safe for stdio).
- Bundle deps with `npm install --omit=dev` and ship `node_modules` inside the plugin, or pre-bundle with `esbuild` to a single file.
- Plugin layout: `${CLAUDE_PLUGIN_ROOT}/server/index.js`, deps at `${CLAUDE_PLUGIN_ROOT}/server/node_modules`.

---

## Python

Install:

```sh
pip install "mcp[cli]"
```

FastMCP (high-level decorator API):

```python
from mcp.server.fastmcp import FastMCP

mcp = FastMCP("my-service")

@mcp.tool()
def add(a: int, b: int) -> int:
    """Add two numbers."""
    return a + b

@mcp.resource("greeting://{name}")
def greet(name: str) -> str:
    return f"Hello, {name}"

if __name__ == "__main__":
    mcp.run(transport="stdio")  # or "streamable-http"
```

FastMCP infers the input schema from type hints and the description from the docstring. For richer schemas (constraints, descriptions per field), use `Annotated[..., Field(...)]` from Pydantic.

**Gotchas:**
- Same stdout rule: do not `print()` — use `logging` configured to write to stderr.
- Ship dependencies via `uv` or a `requirements.txt` plus a venv path; do not assume the user has your packages installed.
- For a plugin-bundled server, distributing a `pyproject.toml` plus a `uv run` invocation in `.mcp.json` is friendlier than asking the user to set up a venv.

---

## Other languages

- **Rust**: `rmcp` (community, async, Tokio-based). Compiles to a single binary — distribute per-platform binaries via a release tarball and reference them from `.mcp.json`. Heavier setup, lightest runtime.
- **Go**: `mcp-go` (community). Same binary-distribution story as Rust.
- **Ruby**: `mcp` gem (official, see `ruby.sdk.modelcontextprotocol.io`). Tools are classes with `description` / `input_schema` / `call` — works well for Rails apps.

For any of these, the protocol contract is the same: implement `initialize`, `tools/list`, `tools/call`, log to stderr, follow the error taxonomy.

---

## Transport

From the server's perspective:

| Transport | Server reads from | Server writes to | Best for |
|---|---|---|---|
| `stdio` | stdin | stdout | Plugin-bundled local servers (default) |
| `streamable-http` | HTTP `POST /mcp` | HTTP response (SSE for streaming, JSON otherwise) | Remote servers, modern recommendation |
| `sse` | HTTP `POST` | SSE event stream | Older remote pattern; superseded by streamable-http for new servers |
| `ws` | WebSocket frames | WebSocket frames | Bidirectional remote; rare in practice |

**Decision rule:** ship `stdio` unless you have a concrete reason to be remote (multi-tenant service, central data store, can't run locally). When remote is required, prefer `streamable-http` — it subsumes `sse` and `http` in one transport.

---

## Streamable HTTP

The modern remote transport. One endpoint accepts `POST` with JSON-RPC; the response is either a JSON body (request/response) or an SSE stream (long-running / streaming).

```ts
import express from "express";
import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { StreamableHTTPServerTransport } from "@modelcontextprotocol/sdk/server/streamableHttp.js";

const server = new McpServer({ name: "my-service", version: "1.0.0" });
// register tools…

const app = express();
app.use(express.json());

app.post("/mcp", async (req, res) => {
  const transport = new StreamableHTTPServerTransport({
    sessionIdGenerator: undefined,
    enableJsonResponse: true,
  });
  res.on("close", () => transport.close());
  await server.connect(transport);
  await transport.handleRequest(req, res, req.body);
});

app.listen(3001);
```

**Gotchas:**
- Sessions: if your server is stateful per-client, generate a `sessionId` and require clients to echo it on each request. If stateless, set `sessionIdGenerator: undefined`.
- Idle timeouts on intermediaries (corporate proxies, load balancers) will kill SSE streams. Send an SSE comment-keepalive (`: ping\n\n`) every 15–30 s.
- TLS (`https://`) is required outside `localhost`. Don't ship `http://` URLs in production examples.

---

## Distribution

If you ship the server inside a plugin:

| Approach | When | Trade-off |
|---|---|---|
| Source + interpreter (Node/Python) | Most plugin-bundled servers | Easiest dev loop; user must have runtime installed |
| Source + bundled deps (`node_modules`, vendored Python) | When the runtime is common but deps are heavy | Plugin grows ~10–100 MB; dev loop unchanged |
| Pre-bundled single file (esbuild for Node, PyInstaller for Python) | When you want one artifact and the user has the runtime | Smaller plugin; lose source-level debuggability |
| Per-platform compiled binary (Rust/Go) | High performance, no runtime dependency | Cross-compile + sign matrix; binary blob in repo |

The `mcp-integration` skill covers the `.mcp.json` shape that points at whichever artifact you ship. Whatever you choose, document the runtime prerequisites in the plugin README — Claude Code will not install Node or Python for the user.
