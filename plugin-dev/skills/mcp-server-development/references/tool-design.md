# MCP Tool Design

Patterns for designing tools agents can actually use. Sourced from Anthropic's "Writing tools for agents" guidance and the MCP spec's tool-definition rules.

## Contents

1. [The shape of a tool](#shape)
2. [Naming](#naming)
3. [Input schemas](#input-schemas)
4. [Output — content, structuredContent, isError](#output)
5. [Granularity — consolidate, don't fragment](#granularity)
6. [Pagination, filtering, truncation](#pagination)
7. [Descriptions that move the needle](#descriptions)
8. [Annotations recap](#annotations)
9. [Worked examples](#worked-examples)

---

## Shape

A tool definition has these fields (spec ≥ 2025-06-18):

| Field | Required | Notes |
|---|---|---|
| `name` | yes | Unique identifier. Snake_case, namespaced (`asana_projects_search`) |
| `title` | no | Human-readable display name |
| `description` | yes (effectively) | The model reads this. Treat as documentation |
| `inputSchema` | yes | JSON Schema. Must be a valid object schema, not `null` |
| `outputSchema` | no | If provided, lets the client validate `structuredContent` |
| `annotations` | no | Behavior hints (`readOnlyHint`, `destructiveHint`, …) |
| `_meta` | no | Server/client-private metadata; not for model consumption |

For tools with no parameters, prefer `{ "type": "object", "additionalProperties": false }` over `{ "type": "object" }` — the explicit form refuses junk arguments.

---

## Naming

**Rules:**

1. **Namespace with the service / domain.** `asana_projects_search`, `gh_issues_create`. Critical when the user has multiple servers loaded — `search` alone is ambiguous; `linear_issues_search` is not.
2. **Verb_noun, not noun_verb.** `create_issue`, not `issue_create`. Reads like the action it performs.
3. **Be specific over general.** `search_contacts` beats `query`. `get_user_by_email` beats `lookup`.
4. **Consistency across your tool set.** Pick `list` or `search`, not both. Pick `id` or `_id`, not both.
5. **No abbreviations the model has to guess.** `cust_addr_upd` is unreadable; `update_customer_address` is not.

---

## Input schemas

The schema is documentation the model reads at call-construction time. Make it carry weight:

```json
{
  "type": "object",
  "properties": {
    "user_id": {
      "type": "string",
      "pattern": "^[A-Z0-9]{8,}$",
      "description": "Customer ID from the CRM (8+ uppercase alphanumerics). NOT the email or display name."
    },
    "limit": {
      "type": "integer",
      "minimum": 1,
      "maximum": 100,
      "default": 20,
      "description": "Max rows to return"
    },
    "after": {
      "type": "string",
      "description": "Opaque cursor from a previous response's `next_cursor` field"
    }
  },
  "required": ["user_id"],
  "additionalProperties": false
}
```

What earns its place:

- **`description` on every property.** Especially when the type alone is ambiguous (`string` could be anything).
- **`pattern` / `enum` / `minimum`-`maximum`** for fields with real constraints. The model will respect them at call time and the SDK will validate at receive time.
- **`default`** on optional fields, so the schema doubles as documentation of the safe baseline.
- **`additionalProperties: false`** at the root unless you genuinely accept open-ended input. Catches typos.
- **Disambiguation in descriptions** when two ID-like things exist: "NOT the email or display name."

---

## Output

A `tools/call` result has this shape:

```ts
{
  content: ContentPart[];          // required
  structuredContent?: object;      // optional, machine-readable mirror
  isError?: boolean;               // true ⇒ tool execution error
  _meta?: object;                  // server-private metadata
}
```

`ContentPart` types:

- `{ type: "text", text: "..." }` — most common
- `{ type: "image", data: "<base64>", mimeType: "image/png" }` — binary properly base64-encoded
- `{ type: "resource", resource: { uri, mimeType, ... } }` — link to a resource the server exposes

### Three patterns for returning data

| Use case | Pattern |
|---|---|
| Free-form text response | One `{type: "text"}` part with the message |
| Structured records | One `{type: "text", text: <JSON.stringify(data)>}` part *and* `structuredContent: data` for clients that prefer typed access |
| Mixed media | Multiple parts — e.g. `[{type:"text",text:"Found 3 matches"}, {type:"image",...}]` |

If you set `outputSchema`, also return `structuredContent` matching it. The text part should be a human-readable rendering — JSON is fine when records are small; for large lists, render a markdown table and put the full JSON in `structuredContent`.

### isError — say so explicitly

`isError: true` tells the client "this call ran but failed at the application layer." The text inside should be actionable:

```json
{
  "content": [{ "type": "text", "text": "User not found: 'jdoe@example.com'. Try `search_users` with a partial name to discover the canonical ID." }],
  "isError": true
}
```

The model sees this and retries with corrected input. Compare to throwing — a thrown exception becomes a JSON-RPC protocol error that the model usually cannot recover from. See `errors-and-logging.md` for the full taxonomy.

---

## Granularity

The instinct to "wrap every endpoint" is wrong. The model has limited context per turn; each tool is overhead. Three rules:

1. **Consolidate chains.** If the agent always calls A then B then C, ship one tool that does A→B→C and lets the server enforce invariants. Anthropic's example: `schedule_event` instead of `find_availability` + `create_event`.
2. **Cut tools that nobody calls.** After a week of real use, look at logs. A tool with zero calls is clutter — delete it.
3. **Split tools that always take a `mode` enum.** A tool that does seven things based on `mode: "list" | "get" | "delete" | …` is seven tools the model has to disambiguate every call. Split it.

---

## Pagination

Always assume the dataset is bigger than the context window. Default to bounded results:

```json
{
  "limit": { "type": "integer", "minimum": 1, "maximum": 100, "default": 20 },
  "after": { "type": "string", "description": "Opaque cursor from `next_cursor`" }
}
```

Return a `next_cursor` in `structuredContent` when there are more results. **Never** return all 50 000 rows — the agent's context fills, the model loses focus, and the user pays for tokens that didn't help.

For text-heavy outputs (logs, file contents), expose a `range` or `head`/`tail` parameter so the agent can fetch what it actually needs.

---

## Descriptions

The description is the most important field on a tool. Anthropic: "Even small refinements to tool descriptions can yield dramatic improvements." Treat it as you'd treat documentation for a new teammate joining the team next week.

A good description answers four questions in 1–4 sentences:

1. **What does this tool do?** (Active verb, specific noun.)
2. **When should the agent use it?** (Cue phrases the model can match against the user's request.)
3. **What does it return?** (One sentence on the shape — "list of records", "the file contents", "true on success".)
4. **What are the gotchas?** (Token cost, rate limits, "prefer X over Y", "this writes to prod".)

### Bad

```
Searches for things.
```

### Better

```
Search the contact directory by name, email, or phone fragment.

Returns up to `limit` matches sorted by relevance, with each match including
`name`, `email`, `phone`, and `id`. Prefer this over `list_all_contacts` for
any query — the directory has 50k+ rows and listing exhausts the context.
```

---

## Annotations recap

Set them honestly. From the spec:

| Annotation | Default | Set to |
|---|---|---|
| `readOnlyHint` | `false` | `true` on every search/list/get/read tool |
| `destructiveHint` | `true` (when not read-only) | `false` only for additive-only tools (e.g., create, append-only insert) |
| `idempotentHint` | `false` | `true` for upsert-by-key, set-state-to-X tools |
| `openWorldHint` | `true` | `false` when the tool's domain is bounded (a local DB, an in-memory store) |

Claude Code uses `readOnlyHint` to decide whether to auto-approve. **Do not lie** to suppress prompts. The first user who notices loses trust in every annotation you ship.

---

## Worked examples

### Search tool (read-only)

```ts
server.registerTool(
  "linear_issues_search",
  {
    title: "Search Linear issues",
    description:
      "Search Linear issues by free-text query. Matches against title, description, and comments. " +
      "Returns up to `limit` issues with id, title, state, assignee, and url, sorted by relevance. " +
      "Prefer this over listing all issues — the workspace has 10k+ rows.",
    inputSchema: {
      query: z.string().min(1).describe("Free-text query"),
      limit: z.number().int().min(1).max(50).default(20),
      state: z.enum(["open", "closed", "all"]).default("open"),
    },
    annotations: { readOnlyHint: true, openWorldHint: false },
  },
  async ({ query, limit, state }) => {
    const issues = await linear.search(query, { limit, state });
    return {
      content: [{
        type: "text",
        text: issues.length ? renderTable(issues) : "No matches.",
      }],
      structuredContent: { issues },
    };
  },
);
```

### Mutation tool (destructive, gated)

```ts
server.registerTool(
  "linear_issues_close",
  {
    title: "Close a Linear issue",
    description:
      "Close a single Linear issue. Set `confirm: \"yes\"` to actually close; otherwise returns a dry-run preview.",
    inputSchema: {
      issue_id: z.string().regex(/^[A-Z]+-\d+$/).describe("Issue ID like ENG-1234"),
      comment: z.string().optional().describe("Closing comment"),
      confirm: z.literal("yes").optional().describe("Set to \"yes\" to actually close"),
    },
    annotations: { readOnlyHint: false, destructiveHint: true, idempotentHint: true, openWorldHint: false },
  },
  async ({ issue_id, comment, confirm }) => {
    if (confirm !== "yes") {
      return { content: [{ type: "text", text: `Dry run: would close ${issue_id}${comment ? ` with comment: "${comment}"` : ""}. Re-run with confirm: "yes".` }] };
    }
    try {
      await linear.close(issue_id, comment);
      return { content: [{ type: "text", text: `Closed ${issue_id}.` }] };
    } catch (e) {
      return {
        content: [{ type: "text", text: `Failed to close ${issue_id}: ${e.message}. Verify the ID with \`linear_issues_search\`.` }],
        isError: true,
      };
    }
  },
);
```
