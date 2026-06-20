# OpenClaw gateway config and workspace reference

`openclaw.json`, the agent workspace bootstrap files, MCP wiring, and the security posture that frames all automation. All facts verified 2026-06-09 against docs.openclaw.ai/gateway/configuration, docs.openclaw.ai/concepts/agent-workspace, docs.openclaw.ai/cli/mcp, and docs.openclaw.ai/gateway/security, OpenClaw 2026.6.5.

## openclaw.json

Location: `~/.openclaw/openclaw.json` (override with `OPENCLAW_CONFIG_PATH`).

- **JSON5** — comments and trailing commas are fine.
- **STRICT schema** — **one unknown key prevents Gateway start**. Never add speculative keys; check the schema first.
- `openclaw doctor` diagnoses config problems; `openclaw doctor --fix` also migrates legacy state (e.g. cron's old `jobs.json`). A **last-known-good config is kept**, so a bad edit is recoverable.
- **Hot reload is hybrid**: most keys apply live, but **gateway port / auth / TLS need a restart**.
- Env layering: process env + `./.env` + `~/.openclaw/.env`, with `${VAR}` substitution inside the config.

```json5
// openclaw.json — shape sketch
{
  // gateway: port/auth/TLS changes need a restart
  gateway: { /* … */ },
  skills: { load: { watch: true, watchDebounceMs: 500, extraDirs: [] }, entries: { /* … */ } },
  plugins: { /* see openclaw-plugin-development */ },
  hooks: { /* webhooks: see webhooks-and-heartbeat.md */ internal: { /* see hooks-and-cron.md */ } },
  cron: { enabled: true },
  agents: { defaults: { skills: [/* allowlist */] }, list: [] },
  mcp: { servers: { /* below */ } },
}
```

## Agent workspace

The workspace (`~/.openclaw/workspace`, or `workspace-<profile>` per profile) carries the bootstrap files injected at session start:

| File | Role |
|---|---|
| `AGENTS.md` | Operating instructions |
| `SOUL.md` | Persona/voice |
| `USER.md` | Who the user is |
| `IDENTITY.md` | Who the agent is |
| `TOOLS.md` | Tool conventions and notes |
| `HEARTBEAT.md` | Heartbeat checklist (see `webhooks-and-heartbeat.md`) |
| `BOOTSTRAP.md` | One-time setup instructions (first run) |
| `BOOT.md` | Gateway-restart checklist, executed via the bundled `boot-md` hook |
| `MEMORY.md` + `memory/YYYY-MM-DD.md` | Long-term + daily memory |

Budgets: `bootstrapMaxChars` **20,000 per file**, `bootstrapTotalMaxChars` **60,000 total**. Oversized bootstrap files get truncated — keep them lean and push depth into files the agent reads on demand.

## MCP — both directions

### Consuming servers: `mcp.servers`

```json5
{
  mcp: {
    servers: {
      github: {
        transport: "streamable-http",   // stdio | sse | streamable-http
        url: "https://mcp.example.com/github",
        auth: "oauth",                  // authorize with: openclaw mcp login github
        toolFilter: { include: ["search_*"], exclude: ["delete_*"] },
      },
    },
  },
}
```

- Transports: **stdio**, **SSE**, **streamable-http**.
- `auth: "oauth"` pairs with `openclaw mcp login <server>`.
- `toolFilter` include/exclude trims what the agent sees.

### Serving: `openclaw mcp serve`

Exposes OpenClaw conversations **as an MCP server**, so other MCP clients can drive the agent. Treat it as a privileged surface — gate it like the gateway itself.

## Security posture

Per docs.openclaw.ai/gateway/security — the frame for every automation decision:

- Prompt injection is **"real, not fully solvable"**. Soft instructions are not enforcement.
- **Hard enforcement** is: tool policy, exec approvals, **sandboxing** (docker; `workspaceAccess: none|ro|rw`), **channel allowlists**, and **`dmPolicy` pairing**.
- **Special-token literals are stripped** from inbound content — don't rely on smuggled control tokens, and don't be surprised when they vanish.
- Keep **`allowUnsafeExternalContent: false`** — flipping it widens the injection surface for every webhook, channel, and MCP server you wire.
- Webhook tokens: dedicated secrets, header-only (see `webhooks-and-heartbeat.md`). Plugins: in-process trusted code (see the openclaw-plugin-development skill).

## Config-change checklist

1. Edit `openclaw.json` (JSON5 — comments fine), only keys you can point to in the docs.
2. `openclaw doctor` — strict schema means an unknown key blocks Gateway start.
3. Hot reload covers most keys; restart for gateway port/auth/TLS (`openclaw gateway restart`).
4. If the Gateway won't start: doctor again — last-known-good is kept; diff against it.
5. Secrets via `${VAR}` from `.env` layers, not inline.

## Sources

- [docs.openclaw.ai/gateway/configuration](https://docs.openclaw.ai/gateway/configuration) — JSON5, strict schema, doctor, last-known-good, hot reload, env layering. Verified 2026-06-09 (OpenClaw 2026.6.5).
- [docs.openclaw.ai/concepts/agent-workspace](https://docs.openclaw.ai/concepts/agent-workspace) — bootstrap files, budgets, workspace profiles. Verified 2026-06-09.
- [docs.openclaw.ai/cli/mcp](https://docs.openclaw.ai/cli/mcp) — mcp.servers transports, oauth login, toolFilter, mcp serve. Verified 2026-06-09.
- [docs.openclaw.ai/gateway/security](https://docs.openclaw.ai/gateway/security) — injection posture, hard enforcement, token stripping, allowUnsafeExternalContent. Verified 2026-06-09.
