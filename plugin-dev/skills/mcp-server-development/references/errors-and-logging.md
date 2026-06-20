# Errors & Logging

Two channels, two taxonomies. Get them wrong and the model can't recover, the user can't debug, and the JSON-RPC stream silently dies.

## Contents

1. [Two kinds of error](#two-kinds)
2. [JSON-RPC error codes](#error-codes)
3. [Writing a recoverable execution error](#recoverable)
4. [Logging — stderr only on stdio](#logging)
5. [Structured logs via the `logging` capability](#mcp-logging)
6. [Crashes & unhandled rejections](#crashes)
7. [Patterns by SDK](#patterns)

---

## Two kinds

| Kind | Where it goes | Model can recover? | Use for |
|---|---|---|---|
| **Protocol error** | Top-level JSON-RPC `error` field | Usually no | Unknown method/tool, malformed params, server internal crash |
| **Tool execution error** | Inside `result` with `isError: true` | Yes — that's the point | Validation, business rule, upstream API failure |

The wrong choice has real cost. Throw on a bad date and the model sees `Unknown error in tool call`. Return `isError: true` with `"Invalid departure date: must be in the future. Today is 2026-05-03."` and the model says "okay, I'll use tomorrow."

---

## Error codes

JSON-RPC 2.0 error codes for protocol errors:

| Code | Meaning |
|---|---|
| `-32700` | Parse error (malformed JSON) |
| `-32600` | Invalid request (not a valid request object) |
| `-32601` | Method not found |
| `-32602` | Invalid params |
| `-32603` | Internal error |
| `-32000` to `-32099` | Server-defined |

Most SDKs handle these for you — you don't write JSON-RPC errors by hand. You **do** decide whether to throw (→ protocol error) or return `isError: true` (→ execution error).

---

## Recoverable

Make execution errors actionable. The model reads them and constructs the next call. Three rules:

1. **Say what's wrong.** Not "invalid input" — name the field and the problem.
2. **Say how to fix it.** Suggest the right format, the right tool, the right next step.
3. **Don't leak internals.** Stack traces, SQL queries, file paths inside the server are noise (and sometimes secrets).

Examples:

```jsonc
// ❌ Useless
{ "content": [{ "type": "text", "text": "Error" }], "isError": true }

// ❌ Leaky
{ "content": [{ "type": "text", "text": "Error: ENOENT, open '/Users/jdoe/secrets/db.sqlite'" }], "isError": true }

// ✅ Actionable
{ "content": [{ "type": "text", "text": "User 'jdoe@example.com' not found. Try `search_users` with a partial name to find the canonical ID." }], "isError": true }

// ✅ Actionable, validation
{ "content": [{ "type": "text", "text": "Invalid departure_date '2024-01-15': must be in the future. Today is 2026-05-03." }], "isError": true }

// ✅ Actionable, upstream
{ "content": [{ "type": "text", "text": "Linear API returned 429 (rate limited). Retry after ~30 s, or reduce `limit` from 100 to 25." }], "isError": true }
```

### When to throw (→ protocol error)

- The tool name doesn't exist (the SDK does this for you).
- Params fail JSON-Schema validation in a way that means the *call shape* is wrong, not the *value* (e.g., `limit` is a string instead of a number — the model needs to be told via the schema, not the result).
- An unrecoverable server bug. Catch it, log to stderr, and rethrow — let the SDK turn it into `-32603 Internal error`.

### When to return `isError: true` (→ execution error)

- Input is well-formed but logically wrong (wrong date, missing record, business rule violation).
- Upstream API failure that the model could retry differently (rate limit, transient 5xx).
- Authorization failure that has a remediation path ("user lacks `issues:write`; ask the operator to grant it").

---

## Logging

**On stdio:** `stdout` is the protocol channel. A single stray write to stdout corrupts the JSON-RPC framing and the connection drops. Use stderr for everything human-readable:

```ts
// ❌
console.log("Server started");

// ✅
console.error("Server started");
```

```python
# ❌
print("Server started")

# ✅
import logging, sys
logging.basicConfig(stream=sys.stderr, level=logging.INFO)
logging.info("Server started")
```

Claude Code captures stderr from stdio MCP servers and surfaces it in the debug view (`/mcp` or the debug log). That makes stderr visible — keep it free of secrets.

**On streamable-http:** stdout is fine, since the protocol channel is HTTP. But still — never log secrets, regardless of transport.

---

## MCP logging capability

The protocol has a `logging` capability that lets the server send structured log messages *to the client over JSON-RPC*. Declare it in `initialize`:

```json
{ "capabilities": { "logging": {} } }
```

Then send `notifications/message` with a level (`debug` | `info` | `notice` | `warning` | `error` | `critical` | `alert` | `emergency`) and a payload:

```json
{
  "jsonrpc": "2.0",
  "method": "notifications/message",
  "params": { "level": "info", "logger": "my-service", "data": { "msg": "Indexed 1234 docs" } }
}
```

This is structured, the host renders it in its log UI, and it's transport-agnostic. Use it for operational events worth surfacing to the user; keep stderr for raw debugging.

---

## Crashes

An uncaught exception in a stdio server kills the process — the host sees a closed pipe and either reconnects or surfaces "MCP server disconnected." Catch at the top:

```ts
process.on("unhandledRejection", (err) => {
  console.error("Unhandled rejection:", err);
  process.exit(1);
});

process.on("uncaughtException", (err) => {
  console.error("Uncaught exception:", err);
  process.exit(1);
});
```

```python
import sys, traceback, signal

def _crash(exc):
    traceback.print_exception(exc, file=sys.stderr)
    sys.exit(1)

sys.excepthook = lambda *args: _crash(args[1])
```

For long-running servers (streamable-http), catch and log per-request — don't let one bad request take down the process.

---

## Patterns by SDK

### TypeScript

```ts
server.registerTool("my_tool", { /* meta */ }, async (input) => {
  try {
    const result = await doWork(input);
    return { content: [{ type: "text", text: render(result) }], structuredContent: result };
  } catch (e) {
    if (e instanceof ValidationError) {
      return { content: [{ type: "text", text: `Invalid: ${e.message}` }], isError: true };
    }
    if (e instanceof UpstreamError) {
      return { content: [{ type: "text", text: `Upstream ${e.status}: ${e.hint}` }], isError: true };
    }
    console.error("my_tool unexpected error:", e);
    throw e; // → protocol error -32603
  }
});
```

### Python (FastMCP)

```python
from mcp.server.fastmcp import FastMCP, ToolError

mcp = FastMCP("my-service")

@mcp.tool()
def get_user(user_id: str) -> dict:
    """Fetch a user by canonical ID."""
    try:
        return repo.get(user_id)
    except UserNotFound as e:
        # Surface as an execution error the model can recover from
        raise ToolError(f"User {user_id!r} not found. Try `search_users` with a partial name.") from e
```

`ToolError` (or whatever the SDK exposes for "execution error with `isError: true`") is the recovery path. Plain exceptions become protocol errors.
