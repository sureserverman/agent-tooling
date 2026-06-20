# OpenClaw plugin format reference

Native OpenClaw plugins field-by-field: both manifests, the entry module, tool registration, install sources, the `plugins` config block, lifecycle, and the security doctrine. All facts verified 2026-06-09 against docs.openclaw.ai/plugins/building-plugins, docs.openclaw.ai/tools/plugin, and docs.openclaw.ai/gateway/security, OpenClaw 2026.6.5.

## Runtime model

- TypeScript **ESM**, Node **22.19+**.
- Plugins load **in-process with the Gateway** — same process, same privileges. This drives every security rule below.
- Two formats:
  - **Native plugin** — `openclaw.plugin.json` + an in-process runtime module. Full API.
  - **Compatible bundle** — maps Codex/Claude/Cursor plugin layouts into OpenClaw's inventory (skills, prompts). No runtime module; use when porting cross-host content, not when you need tools/channels/hooks.

## Manifest 1: package.json `openclaw` field

```jsonc
{
  "name": "openclaw-weather",
  "version": "1.0.0",
  "type": "module",
  "openclaw": {
    "extensions": ["./index.ts"],
    "compat": {
      "pluginApi": ">=2026.3.24-beta.2",
      "minGatewayVersion": "2026.5.17"
    }
  }
}
```

- `extensions` — entry modules, relative paths that must exist (the validator errors with `openclaw-extensions-missing` when they don't).
- `compat.pluginApi` — **always pin**; the plugin API moves on CalVer and unpinned plugins break silently on Gateway upgrades.
- `compat.minGatewayVersion` — gate features that only exist on newer gateways (e.g. the `tool-plugin` subpath, ≥2026.5.17).

## Manifest 2: openclaw.plugin.json

```jsonc
{
  "id": "weather",
  "name": "Weather",
  "contracts": { "tools": ["weather_lookup"] },
  "toolMetadata": { "weather_lookup": { "optional": true } },
  "activation": { "onStartup": true }
}
```

- `id` — required; the key used in `plugins.entries.<id>`, `plugins.allow`/`deny`, and `slots`.
- `contracts.tools` — the tools the plugin declares it provides.
- `toolMetadata.<tool>.optional: true` — the tool is not active until the user opts in via `tools.allow`.
- `activation.onStartup: true` — load when the Gateway starts.

**Both manifests are required.** A lone `openclaw.plugin.json` without a sibling `package.json` carrying the `openclaw` field does not load (validator: `openclaw-package-field`); a lone `package.json` field without `openclaw.plugin.json` has no id/contracts.

## Entry module

```ts
import { definePluginEntry } from "openclaw/plugin-sdk/plugin-entry";

export default definePluginEntry({
  register(api) {
    api.registerTool({
      name: "weather_lookup",
      description: "Look up current weather for a city.",
      parameters: Type.Object({ city: Type.String() }),
      async execute(_id, params) {
        const text = await lookup(params.city);
        return { content: [{ type: "text", text }] };
      },
    });
  },
});
```

### SDK import rules

- The **root barrel `openclaw/plugin-sdk` is DEPRECATED**. Import from focused subpaths:
  - `openclaw/plugin-sdk/plugin-entry` — `definePluginEntry`
  - `openclaw/plugin-sdk/channel-core` — `defineChannelPluginEntry`, `createChatChannelPlugin` (see `channel-plugins.md`)
  - the `tool-plugin` subpath — **exists only on Gateway ≥2026.5.17**; pair with `compat.minGatewayVersion`.
- The deterministic lane flags quote-exact root-barrel imports in `.ts` files as a warning (`openclaw-sdk-root-barrel`).

### registerTool semantics

- `parameters` is a TypeBox schema (`Type.Object(...)`).
- `execute(_id, params)` returns `{content: [{type: "text", text}]}` (MCP-shaped content array).
- **Name conflicts with core tools → the plugin tool is skipped**, reported only in `openclaw plugins inspect`. No load error.
- **Optional tools** (`toolMetadata.<tool>.optional: true`) require the user to add the tool to `tools.allow` before the agent can use them.

Plugins also get runtime hooks: typed `api.on(...)` for specific events versus the coarse `api.registerHook(...)` — prefer the typed surface (see the openclaw-automation skill).

## Install and lifecycle

```bash
openclaw plugins install clawhub:<pkg>
openclaw plugins install npm:<pkg>
openclaw plugins install git:github.com/<owner>/<repo>@<ref>
openclaw plugins install ./local-dir --link     # dev: symlink instead of copy
openclaw plugins enable|disable|list|update|inspect <id>
```

- `--link` keeps a local checkout live for development.
- **Gateway restart is required after install/update/uninstall**: `openclaw gateway restart`. Managed gateways auto-restart; self-hosted ones do not — the number-one "plugin missing" cause.
- `openclaw plugins inspect <id>` shows what actually registered, including skipped tool-name conflicts.

## The `plugins` config block

```json5
// openclaw.json
{
  plugins: {
    enabled: true,
    allow: ["weather", "memory-core"],   // exclusive when present — anything not listed is off
    deny: ["sketchy-plugin"],            // deny wins over allow
    load: { paths: ["~/dev/my-plugins"] },
    slots: { memory: "memory-core" },    // one plugin per named slot
    entries: {
      weather: { enabled: true, config: { units: "metric" } },
    },
  },
}
```

- `allow` is **exclusive**: when present, unlisted plugins do not load.
- `deny` **wins** over `allow`.
- `slots` bind exactly one plugin to a named capability slot (e.g. `memory`).
- Per-plugin config rides in `entries.<id>.config`.

## Security doctrine

Per docs.openclaw.ai/gateway/security, plugins are **trusted code running in the Gateway process** — there is no sandbox between a plugin and your Gateway's credentials and channels. Doctrine:

1. **Allowlist** (`plugins.allow`) rather than installing freely.
2. **Pin exact versions** — `git:…@<tag-or-commit>`, never a branch; ClawHub installs are commit-pinned since 2026.6.5.
3. **Inspect before enabling**: `openclaw plugins inspect` after install, before `enable`.
4. The **`security.installPolicy` hook runs before any install proceeds** — use it to enforce org policy (sources, signatures, allowlists) mechanically.

## Sources

- [docs.openclaw.ai/plugins/building-plugins](https://docs.openclaw.ai/plugins/building-plugins) — manifests, entry, registerTool, SDK subpaths. Verified 2026-06-09 (OpenClaw 2026.6.5).
- [docs.openclaw.ai/tools/plugin](https://docs.openclaw.ai/tools/plugin) — install sources, CLI, config block, restart. Verified 2026-06-09.
- [docs.openclaw.ai/gateway/security](https://docs.openclaw.ai/gateway/security) — in-process trust, installPolicy. Verified 2026-06-09.
