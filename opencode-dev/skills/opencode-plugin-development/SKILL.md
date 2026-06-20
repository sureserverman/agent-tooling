---
name: opencode-plugin-development
description: Use when authoring an OpenCode (opencode.ai terminal agent) plugin or custom tool. Triggers on "OpenCode plugin", "opencode JS plugin", ".opencode/plugins", "tool.execute.before", "OpenCode hook", "publish opencode plugin to npm", "OpenCode custom tool", ".opencode/tools", "@opencode-ai/plugin".
---

# opencode-plugin-development

OpenCode (the opencode.ai terminal agent — source at **github.com/anomalyco/opencode** after the SST→Anomaly rebrand in 2026; ignore unofficial mirrors like open-code.ai or opencodedocs.com, they are NOT canonical and frequently stale) extends through **JavaScript/TypeScript plugins** and **custom tools**. A plugin is a JS/TS module exporting an async function that returns a map of hook handlers; a custom tool is a TS module defining a callable tool the model can invoke. Both are TypeScript-native — OpenCode runs on Bun, no build step.

All facts verified 2026-06-09 against opencode.ai/docs (plugins, custom-tools) and the github.com/anomalyco/opencode repo. Current OpenCode version: **v1.16.x** (June 2026).

## The number-one gotcha: plural directories

**Canonical component directories are plural**: `.opencode/agents/`, `commands/`, `plugins/`, `tools/`, `skills/`, `themes/`. The singular forms (`agent/`, `command/`, `plugin/`, `tool/`, `skill/`, `theme/`) are legacy spellings that are *still read* in most code paths — but they have a history of **silent-ignore bugs**. Issue **#14410** is the canonical example: `opencode agent create` scaffolded into `agent/` while the loader expected `agents/`, so the new agent silently never loaded. Always author plural; the deterministic lane warns on singular dirs (`opencode-singular-dir`).

## Reference map

| When you need… | Read first |
|---|---|
| Plugin loading paths, the exported-function API (`{project, client, $, directory, worktree}`), handler shape, npm distribution, plugin-local dependencies | `references/opencode-plugin-api.md` |
| The full hook event set (~30 events), what each fires on, the v1.15 Effect-core rebuild and why pre-1.15 tutorials mislead | `references/opencode-hook-events.md` |
| Custom tools: `tool()` from `@opencode-ai/plugin`, filename→name rules, multi-export naming, argument schemas, execute context, built-in shadowing | `references/opencode-custom-tools.md` |

## Decision rules

### Plugin, custom tool, agent, or command?

| Signal | Surface |
|---|---|
| React to lifecycle events (block a tool call, watch file edits, mutate shell env, toast the TUI) | **Plugin** (hooks) |
| Give the model a new *callable capability* with typed arguments | **Custom tool** (`.opencode/tools/`) |
| A specialist persona with its own model/permissions/prompt | **Agent** → `opencode-agents-and-commands` |
| A user-typed `/name` prompt template | **Command** → `opencode-agents-and-commands` |
| On-demand procedural knowledge, no code | **Skill** → `opencode-config-and-skills` |

### Where does the plugin live?

- **Project**: `.opencode/plugins/*.{js,ts}` — auto-loaded, committed with the repo.
- **Global**: `~/.config/opencode/plugins/` — every project on the machine.
- **npm**: list the package name in the `"plugin"` array of `opencode.json` — `{"plugin": ["opencode-helicone-session", "@my-org/custom-plugin"]}`. OpenCode auto-installs via Bun into `~/.cache/opencode/node_modules/`. Choose npm when more than one repo or person needs it; otherwise keep it in-repo.

Plugin-local dependencies go in `.opencode/package.json`; types come from `@opencode-ai/plugin`.

### Minimal working plugin

```ts
import type { Plugin } from "@opencode-ai/plugin"

export const EnvGuard: Plugin = async ({ project, client, $, directory, worktree }) => {
  return {
    "tool.execute.before": async (input, output) => {
      if (input.tool === "read" && output.args.filePath?.endsWith(".env"))
        throw new Error("blocked: .env files are off-limits")
    },
  }
}
```

`$` is the **Bun shell** (template-literal subprocess runner), `client` is the OpenCode SDK client (talk back to the running server), `project`/`directory`/`worktree` orient you in the workspace. Throwing inside a `*.before` hook **blocks the operation** — that's the sanctioned veto mechanism.

### Which OpenCode version can you assume?

**v1.15.0 (May 2026) rebuilt event delivery on an Effect-based core.** Before 1.15, hook/event delivery was unreliable (dropped and out-of-order events); tutorials and blog posts written against pre-1.15 describe workarounds you no longer need — and sometimes hook behavior that no longer exists. Treat any pre-May-2026 plugin tutorial as suspect; verify hook names against `references/opencode-hook-events.md`.

## Authoring checklist

1. Pick the surface with the table above; plugins are for *reacting*, tools are for *being called*.
2. Author in TypeScript directly — Bun executes it natively, no transpile step, types from `@opencode-ai/plugin`.
3. Use **plural** directories (`plugins/`, `tools/`).
4. One concern per plugin file; return only the hooks you actually implement (every registered hook costs a dispatch).
5. Gate with the deterministic lane: `bash scripts/validate.sh <artifact-dir>` (from opencode-dev) flags singular dirs, plugins without exports, broken agent/command frontmatter, and deprecated config keys.
6. For distribution beyond one repo, publish to npm and reference via the `"plugin"` config key.

## Anti-patterns this skill catches

- Components in singular dirs (`.opencode/plugin/`, `.opencode/tool/`) — legacy spelling with silent-ignore history (issue #14410); use plural (`opencode-singular-dir`).
- A plugin file with no `export` — never loads, no error (`opencode-plugin-no-export`).
- Porting a Claude Code hooks.json — OpenCode has **no hooks.json**; hooks are functions returned by a plugin module.
- Following pre-1.15 tutorials on event handling — event delivery was rebuilt on an Effect core in v1.15.0.
- Naming a custom tool the same as a built-in *accidentally* — custom tools **shadow** same-named built-ins (deliberate shadowing is a feature; accidental shadowing kills `read`/`bash`/etc.).
- Installing plugin deps into the project's root `package.json` — plugin-local deps belong in `.opencode/package.json`.
- Sourcing facts from open-code.ai or opencodedocs.com — unofficial mirrors; canonical docs are **opencode.ai/docs**, canonical source is **github.com/anomalyco/opencode**.

## Sources

- OpenCode, *Plugins* — loading paths, plugin API, hook handler contract, npm distribution ([opencode.ai/docs/plugins](https://opencode.ai/docs/plugins)). Verified 2026-06-09.
- OpenCode, *Custom Tools* — `tool()` helper, naming, schemas, shadowing ([opencode.ai/docs/custom-tools](https://opencode.ai/docs/custom-tools)). Verified 2026-06-09.
- OpenCode repo — v1.15.0 Effect-core event rebuild, issue #14410 singular-dir scaffold bug ([github.com/anomalyco/opencode](https://github.com/anomalyco/opencode)). Verified 2026-06-09.

When upstream behavior changes, update the references — not this SKILL.md.
