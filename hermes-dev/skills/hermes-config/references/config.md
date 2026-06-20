# Hermes configuration: home, surfaces, providers, context files

Facts verified 2026-06-09 against hermes-agent.nousresearch.com/docs and
github.com/NousResearch/hermes-agent, Hermes Agent v0.16.0 "The Surface
Release" (June 5, 2026). Hermes ships multiple minor releases per month —
re-verify config keys before shipping.

## Home and install

| | |
|---|---|
| HERMES_HOME | `~/.hermes/` (Linux/macOS), `%LOCALAPPDATA%\hermes\` (Windows — **not** `%USERPROFILE%\.hermes\`) |
| Primary config | `<HERMES_HOME>/config.yaml` |
| Install | curl installer (Linux/macOS), PowerShell installer (Windows), or PyPI (`pip install hermes-agent`) |

## Surfaces

All surfaces share one config.yaml and one set of context files:

| Surface | Entry |
|---|---|
| CLI / TUI | `hermes`, `hermes --tui` |
| Messaging gateway | 23 platforms incl. Telegram, Discord, Slack, WhatsApp, Signal |
| Web dashboard | bundled web UI |
| Desktop app | released June 2, 2026 (part of the v0.16 "Surface" push) |

## Providers

Provider-agnostic by design:

- **Nous Portal** — 300+ models; set up with `hermes setup --portal`.
- **Local proxies** — Ollama / llama.cpp-style OpenAI-compatible endpoints.
- **OAuth providers** — sign-in flows for hosted providers.

Model/provider selection lives in config.yaml. Skills and plugins should stay
model-agnostic; if a skill genuinely needs a capability tier, say so in prose,
don't pin a model id.

## Context files

| File | Scope | Purpose |
|---|---|---|
| `SOUL.md` | HERMES_HOME | global persona/identity — "who Hermes is" |
| `MEMORY.md` | HERMES_HOME | durable cross-session facts (world state) |
| `USER.md` | HERMES_HOME | durable facts about the user |
| `.hermes.md`, `HERMES.md`, `AGENTS.md`, `CLAUDE.md`, `.cursorrules` | project root | per-project briefing, auto-loaded |

Project-context discovery checks the project root for any of the five names —
an existing `CLAUDE.md` or `AGENTS.md` works unchanged; don't fork it into a
HERMES.md duplicate. MEMORY.md is also the surface that memory-provider
plugins replace (see hermes-plugin-development).

## Built-in tools

40+ built-in tools, configured via:

```bash
hermes tools            # list, enable/disable, per-tool config
```

Toolset availability interacts with skills' `requires_toolsets` /
`fallback_for_toolsets` frontmatter (see hermes-skills).

## Migrating from OpenClaw

```bash
hermes claw migrate
```

Imports an OpenClaw setup — skills and workspace — into HERMES_HOME. Run it
first; hand-port only what it leaves behind.

Verified 2026-06-09 — hermes-agent.nousresearch.com/docs (configuration,
getting-started), github.com/NousResearch/hermes-agent, v0.16.0.
