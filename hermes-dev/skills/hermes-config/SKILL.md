---
name: hermes-config
description: Use when configuring Hermes Agent — config.yaml, persona/context files, or MCP wiring. Triggers on "Hermes config.yaml", "SOUL.md", "Hermes MCP", "hermes mcp serve", "Hermes persona", "MEMORY.md", "Hermes Telegram/Discord gateway", "hermes claw migrate".
---

# hermes-config

Hermes Agent configures from **`~/.hermes/config.yaml`** (Windows: `%LOCALAPPDATA%\hermes\`), takes its identity from **SOUL.md**, its durable facts from **MEMORY.md/USER.md**, and auto-loads project context from `.hermes.md`, `HERMES.md`, `AGENTS.md`, **`CLAUDE.md`**, or `.cursorrules` — an existing CLAUDE.md works unchanged. MCP servers go under `mcp_servers:` (stdio and HTTP, OAuth 2.1, mTLS), and `hermes mcp serve` exposes Hermes itself **as** an MCP server.

All facts verified 2026-06-09 against hermes-agent.nousresearch.com/docs and github.com/NousResearch/hermes-agent, Hermes Agent v0.16.0 "The Surface Release" (June 5, 2026). **Hermes ships multiple minor releases per month** (v0.14→v0.16 within May–June 2026) — re-verify config keys against current docs before shipping.

## Reference map

| When you need… | Read first |
|---|---|
| HERMES_HOME layout, install paths, surfaces (CLI/TUI, gateway, dashboard, desktop), providers/Nous Portal, context files, `hermes tools`, `hermes claw migrate` | `references/config.md` |
| `mcp_servers:` stdio + HTTP shapes, OAuth 2.1, mTLS, the MCP CLI, `/reload-mcp`, `hermes mcp serve` | `references/mcp.md` |

## The shape in 30 seconds

```
~/.hermes/                      # HERMES_HOME (Windows: %LOCALAPPDATA%\hermes\)
├── config.yaml                 # primary config
├── SOUL.md                     # global persona/identity
├── MEMORY.md                   # durable cross-session facts
├── USER.md                     # durable facts about the user
├── skills/<category>/<name>/   # see hermes-skills
├── skill-bundles/
└── plugins/<name>/             # see hermes-plugin-development
```

```yaml
# ~/.hermes/config.yaml
mcp_servers:
  docs:
    command: npx
    args: ["-y", "@example/docs-mcp"]      # stdio
  search:
    url: https://mcp.example.com/sse       # HTTP
    auth: oauth                            # OAuth 2.1
```

## Decision rules

### Which file carries which context?

| Content | File |
|---|---|
| Global persona/identity ("who Hermes is") | `SOUL.md` in HERMES_HOME |
| Durable cross-session facts | `MEMORY.md` (world) / `USER.md` (about the user) |
| Per-project briefing | project root: `.hermes.md`, `HERMES.md`, `AGENTS.md`, `CLAUDE.md`, or `.cursorrules` — auto-loaded; **reuse your existing CLAUDE.md as-is** |

### Which surface?

CLI/TUI (`hermes`, `hermes --tui`), the **messaging gateway** (23 platforms incl. Telegram, Discord, Slack, WhatsApp, Signal), the web dashboard, or the desktop app (released June 2, 2026). All read the same config.yaml + context files — author once.

### Which provider path?

Provider-agnostic: **300+ models via Nous Portal** (`hermes setup --portal`), local proxies (Ollama/llama.cpp-style endpoints), or OAuth providers. Provider config lives in config.yaml; don't hardcode a model into skills or plugins.

### MCP: stdio or HTTP?

Local process → `command`/`args` (stdio). Remote → `url`/`headers`; `auth: oauth` for OAuth 2.1, `client_cert`/`client_key` for mTLS. Every entry needs **either `command` or `url`** — the validator errors with `hermes-config-mcp` otherwise. Curated catalog: `hermes mcp`; install/wire: `hermes mcp install` / `hermes mcp configure`; hot reload: `/reload-mcp`; Hermes-as-server: `hermes mcp serve`.

### Migrating from OpenClaw

`hermes claw migrate` imports an existing OpenClaw setup — skills and workspace — into HERMES_HOME. Run it before hand-porting anything.

## Anti-patterns this skill catches

- Persona text in config.yaml — identity belongs in SOUL.md; config.yaml is for wiring.
- Duplicating CLAUDE.md into HERMES.md — Hermes auto-loads CLAUDE.md from the project root; one file, no fork.
- An `mcp_servers:` entry with neither `command` nor `url` — dead config; the deterministic validator flags it.
- Hardcoding one provider/model into a skill — Hermes is provider-agnostic; keep model choice in config.yaml.
- Editing `%USERPROFILE%\.hermes\` on Windows — the home is `%LOCALAPPDATA%\hermes\`.
- Assuming config keys are stable — v0.14→v0.16 landed in five weeks; re-verify against current docs.

## Deterministic gate

```bash
bash scripts/validate.sh path/to/artifact --json | jq .
```

Flags an unparseable config.yaml (`hermes-config-parse`) and `mcp_servers` entries with neither `command` nor `url` (`hermes-config-mcp`).

## Sources

- Nous Research, *Hermes Agent docs — Configuration* (HERMES_HOME, config.yaml, context files, surfaces, providers, tools) — [hermes-agent.nousresearch.com/docs](https://hermes-agent.nousresearch.com/docs). Verified 2026-06-09, v0.16.0.
- Nous Research, *Hermes Agent docs — MCP* (`mcp_servers:`, OAuth 2.1, mTLS, MCP CLI, `hermes mcp serve`) — [hermes-agent.nousresearch.com/docs](https://hermes-agent.nousresearch.com/docs). Verified 2026-06-09.
- [github.com/NousResearch/hermes-agent](https://github.com/NousResearch/hermes-agent) — v0.16.0 "The Surface Release" (June 5, 2026), desktop app June 2 2026, `hermes claw migrate`. Verified 2026-06-09.

When upstream behavior changes (it does, monthly), update the references — not this SKILL.md.
