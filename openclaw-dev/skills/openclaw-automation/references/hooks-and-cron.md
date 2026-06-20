# OpenClaw internal hooks and cron reference

Event-driven hooks and the Gateway cron scheduler, field-by-field. All facts verified 2026-06-09 against docs.openclaw.ai/automation (hooks, cron), OpenClaw 2026.6.5.

## Internal hooks

### Format

A hook is a **directory** containing `HOOK.md` plus `handler.ts`:

```
session-audit/
├── HOOK.md
└── handler.ts
```

```yaml
# HOOK.md frontmatter
---
name: session-audit
description: Logs every new command to the audit trail.
metadata: {"openclaw": {"emoji": "🪝", "events": ["command:new"], "requires": {"bins": ["jq"]}, "os": "darwin", "always": false, "export": false, "install": []}}
---
```

The `metadata` value follows the same **single-line JSON** rule as skills (`"openclaw"` key; same `requires`/`os`/`always`/`install` gating vocabulary, plus `events` and `export`). The deterministic lane errors when `metadata.openclaw.events` is missing or empty (`openclaw-hook-events`) and when a `HOOK.md` directory has no `handler.ts` (`openclaw-hook-handler-missing`).

```ts
// handler.ts — default-export an async handler
export default async function handler(event: {
  type: string;        // e.g. "command"
  action: string;      // e.g. "new"
  sessionKey: string;
  timestamp: string;
  messages: unknown[];
  context: Record<string, unknown>;
}) {
  // react; keep it fast — hooks run in the Gateway
}
```

### Events

| Group | Events |
|---|---|
| Commands | `command:new`, `command:reset`, `command:stop` |
| Agent | `agent:bootstrap` |
| Gateway | `gateway:startup`, `gateway:shutdown` |
| Messages | `message:received`, `message:sent` |
| Sessions | `session:compact:before`, `session:compact:after` |

### Precedence and locations

Load order: **bundled → plugin hooks → managed `~/.openclaw/hooks/` → workspace `<workspace>/hooks/`**. Workspace hooks are **disabled by default** — enable them deliberately; they are repo-controlled code running in your Gateway.

### CLI and config

```bash
openclaw hooks list
openclaw hooks info <name>
openclaw hooks enable|disable <name>
openclaw hooks check          # validates hook dirs
```

```json5
// openclaw.json
{
  hooks: {
    internal: {
      enabled: true,
      entries: { "session-audit": { enabled: true } },
      load: { extraDirs: ["~/dev/my-hooks"] },
    },
  },
}
```

### Bundled hooks

`session-memory`, `bootstrap-extra-files`, `command-logger`, `compaction-notifier`, `boot-md` (runs the workspace `BOOT.md` checklist on gateway restart). Read them as living examples before writing your own.

### Plugins and hooks

Plugins get a **typed** runtime event surface — `api.on(...)` per event — and a coarse `api.registerHook(...)`. Prefer `api.on(...)`: typed payloads, narrower contract.

## Cron

The Gateway scheduler. State lives in a **SQLite DB**; legacy `~/.openclaw/cron/jobs.json` installs are migrated by `openclaw doctor --fix`.

### Creating jobs

```bash
openclaw cron create \
  --cron "0 7 * * 1-5" --tz Europe/Vienna \
  --message "Summarize overnight alerts" --session isolated --model sonnet \
  --announce --channel slack --to "#ops"
```

Schedules — one of:

- `--at <timestamp>` — one-shot. **Bare timestamps are UTC**; pass `--tz` for local time.
- `--every <interval>` — fixed interval.
- `--cron <expr>` — 5- or 6-field cron expression, with `--tz`.

### Payload types

| Flag | Runs | Use for |
|---|---|---|
| `--system-event` | Injects an event into the **main session**, no model turn | Nudging state the next turn will see |
| `--message` | A full agent turn — `--session isolated` by default sensible; `--model`, `--thinking` tunable | Scheduled agent work |
| `--command` | A deterministic script **on the Gateway host** | Backups, syncs — anything that needs no model |

Sessions: `main`, `isolated`, `session:<custom-id>`, `current`.

### Delivery

`--announce --channel <ch>` + `to` (post the result to a channel), `webhook` (POST it), or `none`. Pick `none` for jobs whose output nobody reads — session retention still records them.

### Config

```json5
{
  cron: {
    enabled: true,
    maxConcurrentRuns: 2,
    retry: { attempts: 2 },
    sessionRetention: { days: 14 },
  },
}
```

### Cron vs heartbeat

Cron is for **precise timing** — a specific time, a real interval, an exact expression. Heartbeat (see `webhooks-and-heartbeat.md`) is for **context-rich periodic assessment** — one batched main-session turn that checks everything in `HEARTBEAT.md` and stays silent when nothing needs attention. If a job is "check whether X needs doing", it belongs on the heartbeat checklist, not in cron.

## Sources

- [docs.openclaw.ai/automation](https://docs.openclaw.ai/automation) — hook format, events, precedence, CLI; cron schedules, payloads, delivery, SQLite migration. Verified 2026-06-09 (OpenClaw 2026.6.5).
