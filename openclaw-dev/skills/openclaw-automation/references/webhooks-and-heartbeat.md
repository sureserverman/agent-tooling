# OpenClaw webhooks and heartbeat reference

The inbound HTTP automation surface and the periodic heartbeat turn. All facts verified 2026-06-09 against docs.openclaw.ai/automation (webhooks, heartbeat) and docs.openclaw.ai/concepts/agent-workspace, OpenClaw 2026.6.5.

## Webhooks

### Enabling

```json5
// openclaw.json
{
  hooks: {
    enabled: true,
    token: { secret: "webhook-token" },   // DEDICATED secret — never the gateway auth token
    path: "/hooks",
    allowedAgentIds: ["main"],
    allowRequestSessionKey: false,
    allowedSessionKeyPrefixes: ["ext-"],
  },
}
```

### Auth — the rules that bite

- **Bearer header** (`Authorization: Bearer <token>`) or **`x-openclaw-token: <token>`**. Nothing else.
- **Query-string tokens are rejected with 400** — `?token=…` does not work, by design (tokens in URLs leak into logs).
- Use a **dedicated secret**; never reuse the gateway auth token. The webhook token can only wake/message; the gateway token owns everything.
- Scope what callers can do: `allowedAgentIds` (which agents are reachable), `allowRequestSessionKey` + `allowedSessionKeyPrefixes` (whether/which session keys callers may name).

### Endpoints

#### POST /hooks/wake

```json
{ "text": "New invoice arrived in the shared inbox", "mode": "now" }
```

`mode`: `"now"` (immediate turn) or `"next-heartbeat"` (queue it for the next heartbeat batch).

#### POST /hooks/agent

```json
{
  "message": "Triage the failed deploy and report",
  "name": "deploy-triage",
  "agentId": "main",
  "wakeMode": "now",
  "deliver": true,
  "channel": "slack",
  "to": "#ops",
  "model": "sonnet",
  "fallbacks": ["haiku"],
  "thinking": "low",
  "timeoutSeconds": 300
}
```

A full agent run with optional delivery of the result to a channel.

#### POST /hooks/&lt;name&gt; — custom mappings

`hooks.mappings` maps named endpoints to templates, so external systems with fixed payloads (CI, monitoring) get a stable URL with the transformation server-side.

### Gmail watcher

A Gmail Pub/Sub watcher surface exists: `openclaw webhooks` plus the bundled `gog` hook wire Gmail push notifications into the same /hooks pipeline — the reference pattern for push-based mail automation.

## Heartbeat

A **periodic main-session turn** (default **every 30 minutes**) driven by the workspace `HEARTBEAT.md` file:

- The agent wakes, reads `HEARTBEAT.md` as its checklist, checks everything in one batched turn **with full main-session context**, acts where needed, and **stays silent if nothing needs attention**.
- `POST /hooks/wake` with `"mode": "next-heartbeat"` appends external nudges to the next beat instead of forcing an immediate turn.

### Writing HEARTBEAT.md

```markdown
# Heartbeat checklist
- Inbox: anything urgent or from the priority list?
- Calendar: conflicts or prep needed in the next 24h?
- Deploys: any failed pipelines since the last beat?
Stay silent unless something needs me.
```

Rules of thumb:

1. **Batch** — one checklist, not ten cron jobs. The heartbeat's value is shared context across checks.
2. **Make silence the default** — say so explicitly, or every beat produces noise.
3. **Heartbeat ≠ precise timing** — anything that must happen at an exact time is cron (`hooks-and-cron.md`).
4. Keep it short; it is read every beat and competes with bootstrap budgets (`gateway-config.md`).

## Choosing across the four surfaces

| Need | Surface |
|---|---|
| Exact time / interval | Cron |
| React to a Gateway event | Internal hook |
| External system pushes work in | Webhook |
| Periodic "anything need me?" sweep | Heartbeat |
| External event that can wait for the sweep | Webhook `wake` with `next-heartbeat` |

## Sources

- [docs.openclaw.ai/automation](https://docs.openclaw.ai/automation) — webhook endpoints, auth, mappings, Gmail watcher; heartbeat mechanics. Verified 2026-06-09 (OpenClaw 2026.6.5).
- [docs.openclaw.ai/concepts/agent-workspace](https://docs.openclaw.ai/concepts/agent-workspace) — HEARTBEAT.md role among bootstrap files. Verified 2026-06-09.
