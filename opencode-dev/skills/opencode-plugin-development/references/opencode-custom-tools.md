# OpenCode custom tools (verified 2026-06-09, OpenCode v1.16)

Custom tools give the model a new **callable capability** with typed
arguments — distinct from plugins, which *react* to events. (A plugin can also
register tools via its return value, but the file-based form below is the
simple, common path.)

## Location and naming

| Scope | Path |
|---|---|
| Project | `.opencode/tools/<name>.ts` |
| Global | `~/.config/opencode/tools/<name>.ts` |

- **The filename is the tool name**: `.opencode/tools/search-docs.ts` → tool
  `search-docs` (default export).
- **Multiple exports** from one file become `<filename>_<export>`: a file
  `db.ts` exporting `query` and `migrate` yields tools `db_query` and
  `db_migrate`.
- Plural `tools/` is canonical; singular `tool/` is legacy (silent-ignore bug
  history — see the SKILL.md gotcha).

## Shape

```ts
import { tool } from "@opencode-ai/plugin"

export default tool({
  description: "Search the project's documentation index and return matching passages",
  args: {
    q: tool.schema.string().describe("search query"),
    limit: tool.schema.number().optional().describe("max results, default 5"),
  },
  async execute(args, ctx) {
    // args is typed from the schema above
    // ctx carries session/agent context (session id, abort signal, …)
    const hits = await search(args.q, args.limit ?? 5)
    return JSON.stringify(hits)   // return value goes to the model as the tool result
  },
})
```

- `tool()` and `tool.schema` come from **`@opencode-ai/plugin`**.
  `tool.schema` is a Zod-style schema builder (string/number/boolean/enum/
  object/array, `.optional()`, `.describe()`); the descriptions become the
  argument docs the model sees.
- `description` is what the model reads to decide *when* to call the tool —
  write it like a skill description: third person, specific, situational.
- `execute(args, ctx)` is async; return a string (or stringify structured
  data). Throwing surfaces the error to the model as a failed tool call.

## Shadowing built-ins

**A custom tool with the same name as a built-in shadows it.** Built-in tool
names include `read`, `edit`, `glob`, `grep`, `list`, `bash`, `task`,
`webfetch`. This is a feature when deliberate (wrap `bash` with extra
auditing) and a foot-gun when accidental (`.opencode/tools/read.ts` silently
replaces file reading for the whole session). Check your filename against the
built-in list before shipping.

## Tool vs plugin vs MCP — picking the surface

| You want… | Use |
|---|---|
| The model to *call* something with typed args, logic in this repo | **Custom tool** |
| To *react* to lifecycle events / veto operations | **Plugin hook** |
| To expose an external service's existing tool surface | **MCP server** (see `opencode-config-and-skills` → `opencode-mcp-and-themes.md`) |

Custom tools beat MCP for repo-local logic: no server process, no context
bloat from a foreign tool catalog, full Bun/TS access to the workspace.

## Checklist

1. Filename = intended tool name (kebab-case); plural `tools/` dir.
2. `description` says when to call it; every arg has `.describe()`.
3. No accidental collision with built-in names (unless shadowing on purpose).
4. Deterministic results where possible; errors thrown, not encoded in prose.
5. Run opencode-dev's `scripts/validate.sh` over the artifact — it flags
   empty/export-less plugin and tool files (`opencode-plugin-no-export`) and
   singular dirs (`opencode-singular-dir`).

Source: [opencode.ai/docs/custom-tools](https://opencode.ai/docs/custom-tools).
Verified 2026-06-09.
