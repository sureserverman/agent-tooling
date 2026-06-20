# Testing MCP Servers

Three layers of test, smallest to largest. Don't ship without at least the first two.

## Contents

1. [Layer 1 — MCP Inspector smoke test](#inspector)
2. [Layer 2 — protocol-level integration tests](#integration)
3. [Layer 3 — end-to-end with Claude Code](#e2e)
4. [What to test](#what)
5. [CI patterns](#ci)
6. [Common failures the Inspector catches first](#failures)

---

## Inspector

`@modelcontextprotocol/inspector` is the canonical interactive debugger. Spawn your server under it:

```sh
# stdio server
npx @modelcontextprotocol/inspector node ./server/index.js

# Python stdio
npx @modelcontextprotocol/inspector python -m my_service

# remote (streamable-http)
npx @modelcontextprotocol/inspector --transport http http://localhost:3001/mcp
```

The Inspector UI lets you:

- Inspect the `initialize` response — verify `serverInfo`, `protocolVersion`, declared capabilities.
- List tools / resources / prompts — verify names, descriptions, schemas, annotations.
- Call any tool with arbitrary args and see the raw `result` (or `error`).
- Inspect every JSON-RPC message in both directions.

Run the Inspector once before every release. If you ship CI, run it on every PR with a known-good script of tool calls.

---

## Integration tests

For automated coverage, talk to your server over its actual transport. Easiest pattern: spawn it as a subprocess and exchange JSON-RPC frames over stdin/stdout.

### TypeScript example (Vitest)

```ts
import { spawn } from "node:child_process";
import { test, expect } from "vitest";

test("tools/list returns the documented tools", async () => {
  const proc = spawn("node", ["./server/index.js"], { stdio: ["pipe", "pipe", "inherit"] });

  const send = (msg: object) => proc.stdin.write(JSON.stringify(msg) + "\n");
  const receive = (): Promise<any> =>
    new Promise((resolve) => {
      proc.stdout.once("data", (chunk) => resolve(JSON.parse(chunk.toString())));
    });

  send({ jsonrpc: "2.0", id: 1, method: "initialize", params: {
    protocolVersion: "2025-06-18", capabilities: {}, clientInfo: { name: "test", version: "0.0.0" },
  }});
  await receive();

  send({ jsonrpc: "2.0", id: 2, method: "tools/list" });
  const res = await receive();
  expect(res.result.tools.map((t: any) => t.name)).toEqual(["search_contacts", "create_contact"]);

  proc.kill();
});
```

The official SDK also exposes an in-process `Client` you can wire to your `McpServer` without spawning a subprocess — fastest tests, but you bypass the transport. Use both: in-process for fast logic tests, subprocess for transport coverage.

### Python example (pytest)

```python
import json, subprocess, pytest

@pytest.fixture
def server():
    proc = subprocess.Popen(
        ["python", "-m", "my_service"],
        stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True,
    )
    yield proc
    proc.terminate()

def call(server, msg):
    server.stdin.write(json.dumps(msg) + "\n")
    server.stdin.flush()
    return json.loads(server.stdout.readline())

def test_initialize(server):
    res = call(server, {
        "jsonrpc": "2.0", "id": 1, "method": "initialize",
        "params": {"protocolVersion": "2025-06-18", "capabilities": {}, "clientInfo": {"name": "test", "version": "0"}},
    })
    assert res["result"]["serverInfo"]["name"] == "my-service"
```

---

## End-to-end

The realest test: load the plugin into Claude Code, run a session, watch the model call your tools.

- Use `--mcp-debug` (or the equivalent debug flag for your Claude Code version) to see traffic.
- Drive it with a scripted prompt: "Find contacts named Aria and close their open issues." Verify the model picks the right tools and recovers from any errors you've planted.
- Check `/mcp` for connection status and any disconnects mid-session.

This catches issues no unit test will: the model picking the wrong tool because two descriptions overlap, the model passing display names to an `_id` field, the truncation point hitting mid-record.

---

## What

A test pass should cover, at minimum:

| Test | What it proves |
|---|---|
| `initialize` returns `serverInfo`, declared capabilities | Server boots, handshake works |
| `tools/list` matches the documented spec | No drift between code and docs |
| Each tool: happy-path call returns expected shape | Schema → output round-trips |
| Each tool: invalid input → `isError: true` with actionable text | Recoverable errors are recoverable |
| Each destructive tool: `confirm: "yes"` required to mutate | Gating works |
| Path-taking tool: `..` and absolute paths rejected | Traversal guard active |
| Stdout is clean of non-JSON-RPC writes | No `console.log` regressions |
| Stderr does not contain any env var values | No secret leakage |
| Tool output sizes are bounded | No context-window blowups |

The last three are easy to forget and hard to catch interactively. Add them to CI.

---

## CI

Minimal GitHub Actions snippet for a Node MCP server:

```yaml
name: mcp-test
on: [push, pull_request]
jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with: { node-version: '20' }
      - run: npm ci
      - run: npm test                         # in-process + subprocess tests
      - run: |                                # smoke test via Inspector CLI
          timeout 10 npx @modelcontextprotocol/inspector --cli node ./server/index.js \
            --tools list \
            --tools call search_contacts --args '{"query":"Aria","limit":5}'
```

The Inspector has a non-interactive `--cli` mode that exits non-zero on protocol errors — useful as a final gate.

---

## Failures

The Inspector catches these on first run, every time:

| Symptom | Cause |
|---|---|
| Inspector hangs on connect | Server wrote to stdout before/instead of JSON-RPC; check for `console.log` / `print` |
| `tools/list` empty but server claims `tools: {}` | Capability declared, no tools registered |
| Tool call returns `-32603 Internal error` | Unhandled exception in tool body — wrap and return `isError: true` |
| Tool call returns `-32602 Invalid params` for valid-looking input | Schema rejects input — check `additionalProperties: false` and required fields |
| Inspector shows secret in stderr | A log statement included `process.env.SECRET` — redact and re-test |
| Tool description renders blank | `description` field missing or only set on `title` |
| Annotations missing in `tools/list` | Forgot to pass `annotations` to `registerTool` |

Fix at the Inspector level before you wire the server into a plugin — a broken stdio connection in an actual Claude Code session is much harder to diagnose.
