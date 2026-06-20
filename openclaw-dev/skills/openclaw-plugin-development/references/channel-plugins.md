# OpenClaw channel plugin reference

How to build a channel plugin — the plugin type that connects OpenClaw to a chat/messaging surface. All facts verified 2026-06-09 against docs.openclaw.ai/plugins/sdk-channel-plugins, OpenClaw 2026.6.5.

## When a plugin is a channel plugin

Any integration that carries conversations (DMs, group chats, a messaging platform) is a channel plugin, not a plain tool plugin. The channel SDK gives you the pieces a chat surface needs and a plain plugin lacks: DM security policy, pairing, threading, and outbound delivery. **MS Teams is plugin-only since 2026.1.15** — `@openclaw/msteams` is the reference implementation to copy from.

## File anatomy

```
my-channel/
├── package.json            # openclaw field + channel descriptor
├── openclaw.plugin.json    # id, contracts, channelConfigs schema
├── index.ts                # defineChannelPluginEntry
├── setup-entry.ts          # defineSetupPluginEntry (guided setup flow)
└── src/
    └── channel.ts          # createChatChannelPlugin — the actual channel logic
```

### index.ts

```ts
import { defineChannelPluginEntry } from "openclaw/plugin-sdk/channel-core";
import { channel } from "./src/channel.js";

export default defineChannelPluginEntry({ channel });
```

### setup-entry.ts

```ts
import { defineSetupPluginEntry } from "openclaw/plugin-sdk/channel-core";

export default defineSetupPluginEntry({
  // guided setup: collect tokens, register webhooks, verify connectivity
});
```

### src/channel.ts

```ts
import { createChatChannelPlugin } from "openclaw/plugin-sdk/channel-core";

export const channel = createChatChannelPlugin({
  id: "acmechat",
  // DM security: who may open a DM with the agent, pairing flow
  // threading: how platform threads map to OpenClaw sessions
  outbound: {
    async sendText(target, text) { /* deliver */ },
    async sendMedia(target, media) { /* deliver */ },
  },
  // or, for message-shaped platforms: defineChannelMessageAdapter(...)
});
```

`createChatChannelPlugin` owns the chat-channel invariants — DM security, pairing, threading — so each platform plugin implements only transport. Outbound is either the direct `outbound.sendText` / `outbound.sendMedia` pair or a `defineChannelMessageAdapter` when the platform has a richer message model.

## Inbound: HTTP routes

Platform webhooks arrive through the Gateway's HTTP surface:

```ts
api.registerHttpRoute({
  path: "/acmechat/webhook",
  auth: "plugin",          // plugin-scoped auth — do NOT expose unauthenticated routes
  async handler(req, res) { /* verify platform signature, enqueue inbound */ },
});
```

`auth: "plugin"` scopes the route to plugin auth; still verify the platform's own webhook signature inside the handler — the route is reachable from the internet.

## Channel descriptor and config schema

The channel announces itself in `package.json` and declares its per-channel config schema in the plugin manifest:

```jsonc
// package.json
{ "openclaw": {
    "extensions": ["./index.ts"],
    "channel": { "id": "acmechat", "label": "AcmeChat", "blurb": "Chat with your agent on AcmeChat." } } }
```

```jsonc
// openclaw.plugin.json
{ "id": "acmechat",
  "channelConfigs": {
    "acmechat": {
      "schema": {
        "type": "object",
        "properties": { "botToken": { "type": "string" }, "allowFrom": { "type": "array" } },
        "required": ["botToken"]
      } } } }
```

The schema drives validation of users' `channels.<id>` config and the setup UI.

## Design rules

1. **Never skip DM security/pairing.** `createChatChannelPlugin` provides the pairing flow; wiring a channel that accepts DMs from anyone is the classic prompt-injection front door (cf. docs.openclaw.ai/gateway/security: channel allowlists and `dmPolicy` pairing are part of the hard enforcement story).
2. **Thread mapping is product behavior** — decide deliberately whether a platform thread is one OpenClaw session or many; users notice when context bleeds across threads.
3. **Setup flow belongs in `setup-entry.ts`**, not the README — tokens, webhook registration, connectivity checks.
4. **Copy `@openclaw/msteams`** when in doubt; it is the maintained reference for the whole shape.
5. Gateway restart applies here too — channel plugins appear/refresh only after `openclaw gateway restart`.

## Sources

- [docs.openclaw.ai/plugins/sdk-channel-plugins](https://docs.openclaw.ai/plugins/sdk-channel-plugins) — channel anatomy, adapters, HTTP routes, config schema, MS Teams reference. Verified 2026-06-09 (OpenClaw 2026.6.5).
- [docs.openclaw.ai/gateway/security](https://docs.openclaw.ai/gateway/security) — DM policy, channel allowlists. Verified 2026-06-09.
