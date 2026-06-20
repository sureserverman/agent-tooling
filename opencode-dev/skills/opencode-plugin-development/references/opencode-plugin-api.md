# OpenCode plugin API — loading, signature, distribution (verified 2026-06-09, OpenCode v1.16)

## Loading paths

Plugins are auto-loaded from, in both spellings (always author the plural):

| Scope | Path |
|---|---|
| Project | `.opencode/plugins/*.{js,ts}` |
| Global | `~/.config/opencode/plugins/*.{js,ts}` |
| npm | packages listed in the `"plugin"` array of `opencode.json` |

No registration step — every `.js`/`.ts` file in a plugins dir is loaded at
startup. TypeScript is executed natively by Bun; there is **no build step**.

The legacy singular `plugin/` directory is still read but is the historical
source of silent-ignore bugs (issue #14410 class) — see the SKILL.md gotcha.

## The exported function

A plugin module exports one or more **async functions**. Each receives a
context object and returns a map of hook-name → handler:

```ts
import type { Plugin } from "@opencode-ai/plugin"

export const MyPlugin: Plugin = async (ctx) => {
  // ctx fields:
  //   project   — project metadata (id, paths)
  //   client    — OpenCode SDK client: call back into the running server
  //               (sessions, messages, TUI, files) — same surface as
  //               @opencode-ai/sdk
  //   $         — Bun shell: await $`git status`.text()
  //   directory — current working directory
  //   worktree  — worktree root path
  return {
    "session.idle": async (input) => {
      await ctx.$`notify-send "OpenCode" "session idle"`
    },
  }
}
```

Notes:

- The function runs **once at startup**; do setup there (read config, open
  connections), return the handler map.
- Handlers are async; they receive event-specific `input` (and for
  `tool.execute.*`, an `output`/args object they can inspect or mutate).
- **Throwing inside a `*.before` hook blocks the operation** and surfaces the
  error message to the model. This is the sanctioned veto, e.g.:

```ts
"tool.execute.before": async (input, output) => {
  if (input.tool === "read" && output.args.filePath?.includes(".env"))
    throw new Error("Do not read .env files")
}
```

- Multiple exports from one file are all instantiated; multiple files all load.
  Keep one concern per file.

## Types and dependencies

- Types: `@opencode-ai/plugin` (the `Plugin` type, `tool()` helper for custom
  tools, schema helpers). Add it to `.opencode/package.json` as a dev
  dependency for editor IntelliSense — OpenCode itself resolves it regardless.
- **Plugin-local dependencies** go in `.opencode/package.json` (not the
  project's root `package.json`). OpenCode `bun install`s them on load.

## npm distribution

Publish the plugin as a normal npm package whose main export is the plugin
function. Consumers list it in config:

```json
{
  "$schema": "https://opencode.ai/config.json",
  "plugin": ["opencode-helicone-session", "@my-org/custom-plugin"]
}
```

- OpenCode auto-installs the packages via **Bun** into
  `~/.cache/opencode/node_modules/` on startup — users never run an install
  command.
- Scoped packages (`@my-org/...`) work; pin versions with the usual
  `name@1.2.3` syntax if reproducibility matters.
- The `"plugin"` key merges across the config layers (global + project), so a
  team can ship org-wide plugins from the global config and per-repo plugins
  from the project config.

## Versioning caveat

v1.15.0 (May 2026) rebuilt event delivery on an **Effect-based core**. Before
that, hook delivery could drop or reorder events under load. Consequences:

- Pre-1.15 tutorials describing "hooks sometimes don't fire, add retries" are
  obsolete — delete the workaround, require `>=1.15`.
- If a user reports flaky hooks on an old version, the fix is *upgrade*, not
  plugin code.

Source: [opencode.ai/docs/plugins](https://opencode.ai/docs/plugins);
[github.com/anomalyco/opencode](https://github.com/anomalyco/opencode).
Verified 2026-06-09.
