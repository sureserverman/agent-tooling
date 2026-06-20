---
name: openclaw-automation
description: Use when wiring OpenClaw hooks, schedules, webhooks, heartbeats, or gateway configuration. Triggers on "OpenClaw hook", "HOOK.md", "openclaw cron", "OpenClaw webhook", "heartbeat vs cron", "OpenClaw gateway config", "openclaw.json".
---

# openclaw-automation

OpenClaw (2026.6.5) has four automation surfaces plus one config file that gates them all. Picking the wrong surface — or tripping the config's strict schema — is where automations die:

- **Internal hooks** — `HOOK.md` + `handler.ts` directories reacting to typed Gateway events.
- **Cron** — the Gateway scheduler (SQLite state DB) for precise timing.
- **Webhooks** — `POST /hooks/*` for external systems waking the agent.
- **Heartbeat** — a periodic main-session turn driven by `HEARTBEAT.md`, for context-rich checks.
- **`~/.openclaw/openclaw.json`** — JSON5, but **STRICT schema: one unknown key prevents Gateway start**.

All facts verified 2026-06-09 against docs.openclaw.ai (automation/*, gateway/configuration, gateway/security, concepts/agent-workspace, cli/mcp), OpenClaw 2026.6.5.

## Reference map

| When you need… | Read first |
|---|---|
| HOOK.md format, handler contract, hook precedence, event list, hooks CLI/config, bundled hooks; cron payload types, schedules, delivery | `references/hooks-and-cron.md` |
| Webhook endpoints, auth rules, custom mappings; heartbeat mechanics and HEARTBEAT.md | `references/webhooks-and-heartbeat.md` |
| openclaw.json strict schema + doctor, hot reload, env layering, workspace bootstrap files, MCP in both directions, security posture | `references/gateway-config.md` |

## Decision rules

### Which automation surface?

| You want… | Use |
|---|---|
| React to a Gateway event (new command, message sent, compaction, startup) | **Internal hook** |
| Something at an exact time / interval / cron expression | **Cron** — `openclaw cron create --at|--every|--cron` |
| An external system to wake or message the agent | **Webhook** — `POST /hooks/wake` or `/hooks/agent` |
| Periodic "look around and act if needed" with full context | **Heartbeat** — batch checks into `HEARTBEAT.md` |
| A deterministic script on schedule, no model turn | **Cron `--command`** (runs on the Gateway host) |

The canonical rule: **cron for precise timing, heartbeat for context-rich periodic assessment**. Heartbeat (default every 30 min) runs one main-session turn with full context and stays silent if nothing needs attention — don't burn it on exact-time jobs, and don't create ten cron jobs for things one heartbeat checklist covers.

### What does an internal hook look like?

A directory with `HOOK.md` (frontmatter: `name`, `description`, and single-line JSON `metadata: {"openclaw": {"emoji": "…", "events": ["command:new"], …}}`) plus `handler.ts` default-exporting an async handler that receives `{type, action, sessionKey, timestamp, messages, context}`. Events span `command:new|reset|stop`, `agent:bootstrap`, `gateway:startup|shutdown`, `message:received|sent`, `session:compact:before|after`. Precedence: bundled → plugin hooks → managed `~/.openclaw/hooks/` → workspace `<workspace>/hooks/` — and **workspace hooks are disabled by default**. Manage with `openclaw hooks list|info|enable|disable|check` and `hooks.internal.*` config. The validator errors on a `HOOK.md` without a sibling `handler.ts` (`openclaw-hook-handler-missing`) and on missing/empty `events` (`openclaw-hook-events`). Plugins prefer typed `api.on(...)` over coarse `api.registerHook(...)`.

### Which cron payload?

- `--system-event` — injects into the **main session**, no model turn.
- `--message --session isolated [--model --thinking]` — a full agent turn in an isolated session.
- `--command` — a deterministic script on the Gateway host; no model at all.

Sessions: `main` / `isolated` / `session:custom-id` / `current`. Delivery: `--announce --channel <ch> + to`, `webhook`, or `none`. Schedules: `--at`, `--every`, `--cron` (5/6-field, `--tz`; **bare timestamps are UTC**). State lives in a SQLite DB — legacy `~/.openclaw/cron/jobs.json` is migrated by `openclaw doctor --fix`. Limits via `cron.{enabled, maxConcurrentRuns, retry, sessionRetention}`.

### How do external systems call in?

`POST /hooks/wake` (`{"text", "mode": "now"|"next-heartbeat"}`), `POST /hooks/agent` (`{"message", "name", "agentId", "wakeMode", "deliver", "channel", "to", "model", "fallbacks", "thinking", "timeoutSeconds"}`), or custom `POST /hooks/<name>` via `hooks.mappings`. Auth is **Bearer or `x-openclaw-token` header only — query-string tokens are rejected with 400**; use a **dedicated secret, never the gateway auth token**. Scope with `allowedAgentIds`, `allowRequestSessionKey`, `allowedSessionKeyPrefixes`. A Gmail Pub/Sub watcher surface exists (`openclaw webhooks`, bundled `gog`).

### Why won't the Gateway start after my config edit?

`~/.openclaw/openclaw.json` is JSON5 (comments and trailing commas are fine) but the schema is **STRICT — a single unknown key prevents Gateway start**. Run `openclaw doctor` (`--fix` migrates legacy state); a last-known-good config is kept. Hot reload is hybrid: most keys apply live, but gateway port/auth/TLS need a restart. `OPENCLAW_CONFIG_PATH` overrides the location; env comes from the process + `./.env` + `~/.openclaw/.env` with `${VAR}` substitution.

### What about MCP and security posture?

MCP runs both directions: `mcp.servers` consumes stdio/SSE/streamable-http servers (OAuth via `openclaw mcp login`, `toolFilter` include/exclude), and `openclaw mcp serve` exposes conversations *as* an MCP server. Security: the docs call prompt injection "real, not fully solvable" — hard enforcement is tool policy, exec approvals, sandboxing (docker; `workspaceAccess none|ro|rw`), channel allowlists, and `dmPolicy` pairing. Special-token literals are stripped from inbound content; keep `allowUnsafeExternalContent` false.

## Deterministic gate

```bash
bash scripts/validate.sh path/to/artifact --json | jq .
```

Errors on hook dirs missing `handler.ts`, HOOK.md without a non-empty `events` list, and any `openclaw.json` that fails a JSON5-ish parse (`openclaw-config-parse`).

## Anti-patterns this skill catches

- A `HOOK.md` with a multi-line YAML `metadata:` block — same single-line-JSON rule as skills.
- A workspace hook that "never fires" — workspace hooks are disabled by default; enable explicitly.
- Ten cron jobs polling things one `HEARTBEAT.md` checklist would batch — heartbeat exists for exactly this.
- A cron `--at` with a bare timestamp assumed local — bare timestamps are UTC; pass `--tz`.
- Webhook tokens in the query string — rejected (400); Bearer or `x-openclaw-token` header.
- Reusing the gateway auth token as the webhook token — dedicated secret, always.
- Hand-adding a speculative key to `openclaw.json` — strict schema; the Gateway won't start.
- Editing gateway port/auth/TLS and expecting hot reload — those need a restart.

## Sources

- OpenClaw, *Automation* (hooks, cron, webhooks, heartbeat) — formats, events, payloads, auth ([docs.openclaw.ai/automation](https://docs.openclaw.ai/automation)). Verified 2026-06-09 (OpenClaw 2026.6.5).
- OpenClaw, *Gateway configuration* — JSON5, strict schema, doctor, hot reload, env ([docs.openclaw.ai/gateway/configuration](https://docs.openclaw.ai/gateway/configuration)). Verified 2026-06-09.
- OpenClaw, *Agent workspace* — bootstrap files, HEARTBEAT.md, memory ([docs.openclaw.ai/concepts/agent-workspace](https://docs.openclaw.ai/concepts/agent-workspace)). Verified 2026-06-09.
- OpenClaw, *MCP* — `mcp.servers`, `openclaw mcp serve` ([docs.openclaw.ai/cli/mcp](https://docs.openclaw.ai/cli/mcp)); *Gateway security* — injection posture, sandboxing, dmPolicy ([docs.openclaw.ai/gateway/security](https://docs.openclaw.ai/gateway/security)). Verified 2026-06-09.

When upstream behavior changes, update the references — not this SKILL.md.
