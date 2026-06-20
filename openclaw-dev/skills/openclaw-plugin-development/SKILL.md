---
name: openclaw-plugin-development
description: Use when building, installing, or debugging plugins for OpenClaw. Triggers on "OpenClaw plugin", "openclaw.plugin.json", "definePluginEntry", "channel plugin", "OpenClaw plugin SDK", "registerTool in OpenClaw".
---

# openclaw-plugin-development

OpenClaw plugins (OpenClaw 2026.6.5, the open-source personal AI assistant by Peter Steinberger) are TypeScript ESM modules, Node 22.19+, that run **in-process with the Gateway**. The five things that bite authors:

- **Dual manifests, BOTH required**: a `package.json` `openclaw` field AND an `openclaw.plugin.json` — forget either and the plugin won't load.
- The **root SDK barrel `openclaw/plugin-sdk` is DEPRECATED** — import from focused subpaths (`openclaw/plugin-sdk/plugin-entry`, …) and pin `compat.pluginApi`.
- **Install/update/uninstall require a Gateway restart** (`openclaw gateway restart`) — managed gateways auto-restart, self-hosted ones don't.
- Tool name conflicts with core tools are **silently skipped** (surfaced only in `openclaw plugins inspect`); optional tools need user opt-in via `tools.allow`.
- Plugins are **trusted code in the Gateway process** — the security doctrine is allowlists, exact version pins, inspect-before-enable.

All facts verified 2026-06-09 against docs.openclaw.ai (tools/plugin, plugins/building-plugins, plugins/sdk-channel-plugins, gateway/security), OpenClaw 2026.6.5.

## Reference map

| When you need… | Read first |
|---|---|
| Both manifests field-by-field, `definePluginEntry`, SDK subpaths, `registerTool`, install sources, `plugins` config, restart rules, security doctrine | `references/plugin-format.md` |
| Channel plugin anatomy (entry, setup-entry, channel.ts), DM security/pairing/threading, HTTP routes, channel config schema, the MS Teams reference plugin | `references/channel-plugins.md` |

## The shape in 30 seconds

```jsonc
// package.json (manifest 1 of 2)
{ "name": "openclaw-weather", "type": "module",
  "openclaw": { "extensions": ["./index.ts"],
                "compat": { "pluginApi": ">=2026.3.24-beta.2", "minGatewayVersion": "2026.5.17" } } }
```

```jsonc
// openclaw.plugin.json (manifest 2 of 2)
{ "id": "weather", "name": "Weather",
  "contracts": { "tools": ["weather_lookup"] },
  "toolMetadata": { "weather_lookup": { "optional": true } },
  "activation": { "onStartup": true } }
```

```ts
// index.ts — focused subpath, NOT the deprecated root barrel
import { definePluginEntry } from "openclaw/plugin-sdk/plugin-entry";

export default definePluginEntry({
  register(api) {
    api.registerTool({
      name: "weather_lookup",
      description: "Look up current weather for a city.",
      parameters: Type.Object({ city: Type.String() }),
      async execute(_id, params) {
        return { content: [{ type: "text", text: await lookup(params.city) }] };
      },
    });
  },
});
```

## Decision rules

### Native plugin or compatible bundle?

Two formats exist. A **native plugin** (`openclaw.plugin.json` + in-process runtime module) gets the full API: tools, hooks, HTTP routes, channels, slots. A **compatible bundle** maps Codex/Claude/Cursor plugin layouts into OpenClaw's inventory — fine for shipping skills/prompts across hosts, but no in-process runtime. If you need `registerTool` or a channel, it's a native plugin.

### Which SDK subpath?

The root barrel `openclaw/plugin-sdk` is **deprecated** — the deterministic lane warns on it (`openclaw-sdk-root-barrel`). Use focused subpaths: `openclaw/plugin-sdk/plugin-entry` for `definePluginEntry`; the `tool-plugin` subpath exists only on **≥2026.5.17** — gate with `compat.minGatewayVersion`. Always pin `compat.pluginApi`.

### Will my tool actually appear?

Three silent failure modes: (1) a tool whose `name` collides with a core tool is **skipped** — check `openclaw plugins inspect`; (2) tools marked `optional: true` in `toolMetadata` need the user to opt in via `tools.allow`; (3) the plugin itself may be disabled or denied in `plugins` config (`deny` wins over `allow`; `allow` is exclusive when present).

### Plain plugin or channel plugin?

If the plugin connects a chat surface (DMs, a messaging platform), it's a **channel plugin**: `defineChannelPluginEntry` from `openclaw/plugin-sdk/channel-core`, a `setup-entry.ts` (`defineSetupPluginEntry`), and `src/channel.ts` built on `createChatChannelPlugin` (DM security, pairing, threading, outbound `sendText`/`sendMedia` or `defineChannelMessageAdapter`). Inbound traffic arrives via `api.registerHttpRoute({path, auth: "plugin"})`. MS Teams has been plugin-only since 2026.1.15 — `@openclaw/msteams` is the reference implementation. Full anatomy in `references/channel-plugins.md`.

### How do users install and configure it?

```bash
openclaw plugins install clawhub:<pkg> | npm:<pkg> | git:github.com/<o>/<r>@<ref> | ./local [--link]
openclaw plugins enable|disable|list|update|inspect
```

Config under `plugins`: `enabled`, `allow` (exclusive allowlist), `deny` (wins), `load.paths`, `slots` (e.g. `{"memory": "memory-core"}` — one plugin per slot), `entries.<id>.{enabled, config}`. **After any install/update/uninstall the Gateway must restart** (`openclaw gateway restart`); managed gateways do it automatically — self-hosted users forget, and the plugin "isn't there".

### What does security demand?

Plugins run **in-process with the Gateway = trusted code** (docs.openclaw.ai/gateway/security). Doctrine: allowlist plugins (`plugins.allow`), pin exact versions, run `openclaw plugins inspect` before enabling anything, and rely on the `security.installPolicy` hook — it runs before any install proceeds. Never instruct users to install from a floating git ref.

## Deterministic gate

```bash
bash scripts/validate.sh path/to/plugin --json | jq .
```

Errors on a missing/id-less `openclaw.plugin.json` (`openclaw-plugin-manifest`), a missing sibling `package.json` `openclaw` field (`openclaw-package-field`), dangling `openclaw.extensions` paths (`openclaw-extensions-missing`); warns on root-barrel imports (`openclaw-sdk-root-barrel`).

## Anti-patterns this skill catches

- Only one of the two manifests shipped — both `package.json#openclaw` and `openclaw.plugin.json` are required.
- `import { definePluginEntry } from "openclaw/plugin-sdk"` — deprecated root barrel; use the focused subpath.
- Using the `tool-plugin` subpath without `minGatewayVersion: "2026.5.17"` — older gateways fail to load it.
- "Installed but nothing happened" docs that omit `openclaw gateway restart`.
- A tool named like a core tool — silently skipped; rename and re-check with `openclaw plugins inspect`.
- An optional tool the README never tells users to add to `tools.allow`.
- Building a messaging integration as a plain plugin — chat surfaces are channel plugins with DM security and pairing.
- Install instructions pointing at a branch (`git:…@main`) — pin a tag/commit; in-process code deserves exact pins.

## Sources

- OpenClaw, *Plugins* — install sources, CLI, config, restart requirement ([docs.openclaw.ai/tools/plugin](https://docs.openclaw.ai/tools/plugin)). Verified 2026-06-09 (OpenClaw 2026.6.5).
- OpenClaw, *Building plugins* — dual manifests, `definePluginEntry`, SDK subpaths, `registerTool` ([docs.openclaw.ai/plugins/building-plugins](https://docs.openclaw.ai/plugins/building-plugins)). Verified 2026-06-09.
- OpenClaw, *SDK channel plugins* — channel anatomy, adapters, HTTP routes ([docs.openclaw.ai/plugins/sdk-channel-plugins](https://docs.openclaw.ai/plugins/sdk-channel-plugins)). Verified 2026-06-09.
- OpenClaw, *Gateway security* — in-process trust doctrine, `security.installPolicy` ([docs.openclaw.ai/gateway/security](https://docs.openclaw.ai/gateway/security)). Verified 2026-06-09.

When upstream behavior changes, update the references — not this SKILL.md.
