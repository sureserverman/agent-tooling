---
name: mcp-server-development
description: Use when implementing a custom MCP server from scratch. Triggers on "FastMCP", "@modelcontextprotocol/sdk", "MCP tool annotations", "structuredContent", "isError", "JSON-RPC error in MCP".
---

# mcp-server-development

Best practices for **building** a custom MCP server. For wiring an existing server into a plugin via `.mcp.json`, use the sibling `mcp-integration` skill — this skill covers the implementation side.

> **Spec drift warning.** MCP is a young protocol. Field names (`structuredContent`, `_meta`, `isError`), capability shapes, and SDK APIs change between releases. Pin the spec date you target (`2025-06-18`, `2025-11-25`, etc.) in your server's `protocolVersion` and verify field names against `modelcontextprotocol.io/specification/<date>` before shipping. The snippets below target spec ≥ `2025-06-18`.

## Reference map

| When you're… | Read first |
|---|---|
| Designing tools (naming, schemas, return shape) | `references/tool-design.md` |
| Choosing transport / SDK / language | `references/sdk-and-transport.md` |
| Hardening the server (input validation, destructive ops, secrets) | `references/security.md` |
| Reporting errors correctly (protocol vs execution) | `references/errors-and-logging.md` |
| Testing with Inspector + integration harnesses | `references/testing.md` |

---

## 1. Decide before you write code

Answer these before opening an editor:

1. **Tool or skill?** If a Claude Code skill plus Bash/Read/Write/Edit covers the workflow with no cross-process state, write a skill. MCP only earns its keep when you need a real process boundary — a database client, a long-lived index, a remote API session, a browser driver. (Same rule appears in `mcp-integration` §1.)
2. **What tools, exactly?** Write the tool list down with one-sentence descriptions *before* implementing. Anthropic's tool-design rule of thumb: "a few thoughtful tools targeting specific workflows" beats "wrap every API endpoint." Consolidate chained calls (`schedule_event` over `find_availability` + `create_event`).
3. **Which transport?** Default to `stdio` for plugin-bundled servers. Reach for `streamable-http` (or `sse`) only when the server must be remote or stream incremental results. See `references/sdk-and-transport.md`.
4. **Read-only or destructive?** Servers that mutate external state (write to a DB, send email, push to a remote) need destructive-op gating *and* honest tool annotations. See `references/security.md`.

---

## 2. Server skeleton — what every MCP server must do

Independent of SDK or language, every server:

1. Declares `serverInfo` (name + version) and `protocolVersion` (the spec date you tested against).
2. Declares `capabilities` — at minimum `tools: {}`. Add `resources: {}` / `prompts: {}` only if you implement them. Don't claim a capability you don't ship — clients will call into it.
3. Implements `tools/list` (idempotent, no side effects) and `tools/call`.
4. Returns results with `content: [...]` parts. Use `isError: true` for tool-level failures, JSON-RPC `error` only for protocol-level failures (unknown method, malformed params).
5. Logs to **stderr** only when using `stdio` transport. `stdout` is the JSON-RPC channel — a stray `console.log` corrupts it and the connection silently dies.

### Minimal stdio server (TypeScript SDK)

```ts
import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";
import { z } from "zod";

const server = new McpServer(
  { name: "my-service", version: "1.0.0" },
  { capabilities: { tools: {} } },
);

server.registerTool(
  "search_contacts",
  {
    title: "Search contacts",
    description: "Search the contact directory by name, email, or phone fragment. Returns up to `limit` matches sorted by relevance. Prefer this over listing all contacts.",
    inputSchema: {
      query: z.string().min(1).describe("Free-text query — name, email, or phone fragment"),
      limit: z.number().int().min(1).max(100).default(20).describe("Max results to return"),
    },
    annotations: { readOnlyHint: true, openWorldHint: false },
  },
  async ({ query, limit }) => {
    const hits = await db.searchContacts(query, limit);
    return { content: [{ type: "text", text: JSON.stringify(hits) }] };
  },
);

await server.connect(new StdioServerTransport());
console.error("my-service ready"); // stderr, not stdout
```

### Minimal stdio server (Python FastMCP)

```python
from mcp.server.fastmcp import FastMCP

mcp = FastMCP("my-service")

@mcp.tool(annotations={"readOnlyHint": True, "openWorldHint": False})
def search_contacts(query: str, limit: int = 20) -> list[dict]:
    """Search the contact directory by name, email, or phone fragment.

    Returns up to `limit` matches sorted by relevance. Prefer this over
    listing all contacts.
    """
    return db.search_contacts(query, limit)

if __name__ == "__main__":
    mcp.run(transport="stdio")
```

Full SDK comparison + Rust/Go/Ruby pointers: `references/sdk-and-transport.md`.

---

## 3. Tool design — the rules that move the needle

Most MCP servers fail not on protocol, but on tool design. The agent can't use what it can't understand.

| Rule | Why |
|---|---|
| **Few thoughtful tools, not many shallow ones** | Each tool occupies a slot in the model's working set; 30 thin wrappers crowd out the right call |
| **Consolidate chains** (`schedule_event`, not `find_availability` + `create_event`) | Saves round-trips and lets the server enforce invariants |
| **Namespace with a prefix** (`asana_projects_search`) | Disambiguates when multiple servers are loaded into one session |
| **Specific parameter names** (`user_id`, not `user`) | Prevents the agent from passing a display name where an ID is required |
| **Return high-signal fields, not raw IDs** | `name` + `file_type` beats `uuid` + `mime_type` for downstream reasoning |
| **Default to filtered/paginated, not full dumps** | Context windows are finite — `list_all_*` is almost always wrong |
| **Polish the description** | "Even small refinements to tool descriptions can yield dramatic improvements" — treat the description as onboarding doc for a new teammate |

Long-form patterns and worked examples: `references/tool-design.md`.

### Tool annotations — set them honestly

Annotations are **hints**. Clients are required to treat them as untrusted from third-party servers, but Claude Code uses them to decide whether to auto-approve a call:

| Annotation | Meaning | Default |
|---|---|---|
| `readOnlyHint` | Tool does not mutate environment | `false` |
| `destructiveHint` | Tool may perform destructive updates (only meaningful when `readOnlyHint=false`) | `true` |
| `idempotentHint` | Repeating with same args has no further effect (only when `readOnlyHint=false`) | `false` |
| `openWorldHint` | Tool reaches into an open world (web, third-party APIs) vs a closed local domain | `true` |

Set `readOnlyHint: true` on every search/list/get tool — Claude Code can then auto-approve them. Leave the destructive flags accurate; do not lie to suppress prompts. Users will turn on auto-approve once they trust the annotations.

---

## 4. Errors — protocol vs execution

These are not the same thing. Conflating them breaks model recovery.

**Protocol error** — wrong method, malformed params, server crash. Reported via JSON-RPC top-level `error`. The model usually cannot fix this:

```json
{ "jsonrpc": "2.0", "id": 3, "error": { "code": -32602, "message": "Unknown tool: invalid_tool" } }
```

**Tool execution error** — the call was well-formed but the work failed (validation, API error, business rule). Reported inside `result` with `isError: true` and a *helpful* message:

```json
{
  "jsonrpc": "2.0", "id": 4,
  "result": {
    "content": [{ "type": "text", "text": "Invalid departure date: must be in the future. Today is 2026-05-03." }],
    "isError": true
  }
}
```

The model **can** self-correct from execution errors. Write them like you'd write an error message for a junior teammate — say what went wrong and how to fix it. Full taxonomy and SDK-specific patterns: `references/errors-and-logging.md`.

---

## 5. Security — the non-negotiables

From the spec ("Security Considerations"): validate every URI, gate sensitive resources, encode binary properly, check permissions before operations. In practice, that means:

- **Validate every input** against your `inputSchema`. Don't trust the SDK to do this for you on every transport.
- **Path-traversal guard** on any tool that takes a file path: resolve, then check `realpath` is under an allow-list root. Reject `..`, absolute paths outside scope, and symlinks pointing outside.
- **Command injection guard** on any tool that shells out: use `execFile`/`subprocess.run([...])` with an argv array, never `exec`/`shell=True` with string concatenation.
- **Destructive ops require an explicit ack arg**. Don't rely on the host's confirm prompt alone. Pattern: require `confirm: "yes"` or `confirm_dry_run: false` in the input schema; default to dry-run.
- **Secrets via env, never in args or output**. Never echo a token back in a tool result. Never log a token to stderr.
- **Bound output size**. Truncate to a sane limit (e.g., 200 KB) before returning. Unbounded output is a DoS on the agent's context window and a leak vector.

Worked examples + a security review checklist: `references/security.md`.

---

## 6. Test before you ship

Every server gets a smoke test with the MCP Inspector before it touches a plugin:

```sh
npx @modelcontextprotocol/inspector node ./server/index.js
# or for Python:
npx @modelcontextprotocol/inspector python -m my_service
```

Inspector lets you list tools, call them with crafted args, and see the raw JSON-RPC traffic. Verify:

1. `initialize` returns the capabilities you actually implement (no claimed-but-missing).
2. `tools/list` matches your spec — names, descriptions, schemas, annotations.
3. Each tool returns the shape you documented; errors set `isError: true`, not a stack trace in `text`.
4. Nothing leaks to stdout (it would already have broken Inspector — but check stderr for accidental secret echo too).

Integration-test patterns and CI hooks: `references/testing.md`.

---

## 7. Anti-patterns

| Anti-pattern | Why it fails |
|---|---|
| `console.log` in a stdio server | Corrupts the JSON-RPC stream; connection silently dies |
| Returning a stack trace as a successful result | Model trusts it as data; cannot recover |
| Throwing on bad input instead of `isError: true` | Becomes a protocol error → model sees "invalid tool" instead of "fix the date" |
| `list_all_<thing>` with no pagination | Burns the agent's context on the first call |
| Lying with `readOnlyHint: true` on a writing tool | Users disable auto-approve once they catch you; trust never recovers |
| Claiming `resources` capability without implementing `resources/list` | Client calls in, server errors, session degrades |
| Bundling `node_modules` > 100 MB or building a Rust server you don't ship a binary for | Plugin-size bloat or "works on my machine" |
| Hardcoding paths or secrets in the server | Breaks on every machine but the author's; credential leak |
| One giant tool that takes a `mode` enum and does seven things | The model picks the wrong mode; split into seven tools (or three, after consolidation) |
| Skipping the Inspector smoke test | First user becomes the QA team |

---

## Sources

- https://modelcontextprotocol.io/specification/latest — protocol spec (lifecycle, tools, resources, prompts)
- https://modelcontextprotocol.io/llms-full.txt — full spec corpus, machine-readable
- https://modelcontextprotocol.io/docs/tools/inspector — Inspector docs
- https://www.anthropic.com/engineering/writing-tools-for-agents — tool-design guidance from Anthropic
- https://ts.sdk.modelcontextprotocol.io — TypeScript SDK
- https://py.sdk.modelcontextprotocol.io — Python SDK (FastMCP)
- https://code.claude.com/docs/en/mcp — Claude Code MCP integration docs
