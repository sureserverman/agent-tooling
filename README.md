# agent-tooling

A Claude Code plugin marketplace for **authoring extensions on AI coding-agent
platforms** — Claude Code, Claude Cowork, Cursor, OpenAI Codex, OpenCode, Hermes
Agent, and OpenClaw.

These seven plugins form one tightly-coupled family built around `plugin-dev`
(the Claude Code authoring kit and the shared cross-host *determinism kit*). Each
platform sibling owns its platform's half of extension development, ships skills
grounded in June-2026 platform docs, vendors `plugin-dev`'s deterministic
validation lane, and declares a `dependencies` link back to `plugin-dev` so the
family installs and versions together.

> Split out of [`coder-plugins`](https://github.com/sureserverman/coder-plugins)
> in June 2026. Language/app and dev-workflow plugins (rust-dev, android-dev,
> game-dev, planning, git-github, …) still live there.

## Install as a marketplace

```
/plugin marketplace add sureserverman/agent-tooling
```

Then install individual plugins:

```
/plugin install plugin-dev@agent-tooling
/plugin install cowork-dev@agent-tooling
/plugin install cursor-dev@agent-tooling
/plugin install codex-dev@agent-tooling
/plugin install opencode-dev@agent-tooling
/plugin install hermes-dev@agent-tooling
/plugin install openclaw-dev@agent-tooling
```

## Plugins

### plugin-dev — the hub

Lean, security-aware authoring kit for **other** Claude Code plugins, and the
shared cross-host core of the family. Positioned as the 2026-current alternative
to Anthropic's existing plugin-dev (~22k lines), with description-leak audit and
prompt-injection screening baked in.

- **15 skills** — `plugin-structure`, `determinism-boundary`, `skill-development`, `command-development`, `agent-development`, `hook-development` (32 events, five handler types, current to v2.1.170), `mcp-integration`, `mcp-server-development`, `plugin-settings`, `skill-description-leak-audit`, `skill-best-practices-sync`, `creating-subagents` (one definition that works on Claude Code + Codex + Cursor + OpenCode), plus a full **skill lifecycle**: `skill-workshop` (session-history mining), `skill-eval` (rubric-scored effectiveness testing), and `skill-curator` (staleness scan + archive-never-delete maintenance). Each SKILL.md is ≤500 lines with one-level-deep `references/`.
- **5 agents** — `plugin-validator` (haiku, runs the deterministic suite then judges), `skill-reviewer` (haiku, leak-audit + injection scan), `agent-creator` (sonnet, write-capable scaffolder), `session-analyzer` (haiku, session mining), `skill-judge` (sonnet, rubric-scores a skill-eval case).
- **`/create-plugin` + `/refactor-plugin`** — scaffold new plugins balanced on the determinism boundary, or retrofit existing ones.
- **Skill lifecycle** (discover → build → measure → maintain) — see [`plugin-dev/docs/skill-lifecycle.md`](./plugin-dev/docs/skill-lifecycle.md).

Source: [`plugin-dev/`](./plugin-dev)

### Platform siblings

One authoring plugin per AI-tool platform, each with skills grounded in that
platform's June-2026 docs plus a vendored deterministic validator
(`validate-<platform>-artifact.sh` + good/bad fixtures), and a `dependencies`
link back to `plugin-dev`:

| Plugin | Target platform | Owns |
|---|---|---|
| [`cowork-dev/`](./cowork-dev) | Claude Cowork | install paths + package limits, component-support matrix, chat-native patterns |
| [`cursor-dev/`](./cursor-dev) | Cursor 3.x | `.cursor-plugin` manifests + marketplace, `.mdc` rules, skills, camelCase hooks, subagents, MCP |
| [`codex-dev/`](./codex-dev) | OpenAI Codex CLI/IDE | `.codex-plugin` manifests + marketplaces, skills + `agents/openai.yaml`, agent TOML, config.toml (post-0.134 profiles), hooks trust model |
| [`opencode-dev/`](./opencode-dev) | OpenCode | JS/TS plugins + npm distribution, agents (`permission` model), commands, opencode.json, skills, themes |
| [`hermes-dev/`](./hermes-dev) | Hermes Agent (Nous Research) | skills + bundles + taps, Python plugins (`plugin.yaml` + `register(ctx)`), SOUL.md/config.yaml, MCP both directions |
| [`openclaw-dev/`](./openclaw-dev) | OpenClaw | skills (gated `metadata.openclaw`), TS plugins + channel plugins, HOOK.md hooks, cron/webhooks/heartbeat, ClawHub |

## Layout

```
agent-tooling/
├── .claude-plugin/
│   └── marketplace.json
├── README.md
├── bootstrap.sh
├── plugin-dev/                  # the hub: Claude Code authoring + shared determinism kit
│   ├── .claude-plugin/plugin.json
│   ├── skills/
│   ├── agents/
│   └── commands/
├── cowork-dev/
├── cursor-dev/
├── codex-dev/
├── opencode-dev/
├── hermes-dev/
└── openclaw-dev/                # each sibling: skills/ + scripts/ (vendored validator lane)
```

## How the family is coupled

The coupling is real but *not* a runtime dependency — every plugin is
self-contained and runs standalone:

- **Declared `dependencies`** — each sibling lists `{ "name": "plugin-dev" }`, a
  co-install hint. Because plugin `dependencies` resolve from the *same*
  marketplace by default, the family must stay together here.
- **Vendored kit** — each sibling carries its own copy of `plugin-dev`'s
  `scripts/lib/findings.sh` + `validate.sh` (marked "from plugin-dev; do not
  fork"). Re-vendor when the upstream kit changes.
- **Editorial** — siblings defer cross-cutting plugin-authoring judgment
  (leak audit, general structure validation) back to `plugin-dev`.

## Contributing a new platform sibling

```
/plugin install plugin-dev@agent-tooling
/create-plugin <platform>-dev
```

Then give it a `validate-<platform>-artifact.sh` (vendor the kit with
`plugin-dev`'s `scripts/install-kit.sh`), a `dependencies` link to `plugin-dev`,
and register it in `.claude-plugin/marketplace.json`.

## License

MIT — see [`LICENSE`](./LICENSE). Each plugin also carries its own `LICENSE`.
