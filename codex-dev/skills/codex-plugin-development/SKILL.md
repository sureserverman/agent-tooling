---
name: codex-plugin-development
description: Use when authoring or distributing an OpenAI Codex plugin. Triggers on "build a Codex plugin", ".codex-plugin manifest", "Codex marketplace", "codex marketplace add", "share skills via Codex plugin", "plugin.json for Codex", "Codex plugin directory".
---

# codex-plugin-development

Codex plugins bundle **skills, hooks, MCP servers, and app/connector configs** into one installable unit. They reached general availability around Codex CLI v0.117 (April 2026); v0.137–0.138 added `--json` output to the `plugin` and `marketplace` CLI commands. The format superficially resembles Claude Code's, but the manifest directory, manifest fields, and marketplace machinery are all Codex-specific — porting a Claude Code plugin by renaming directories will not work.

All facts verified 2026-06-09 against developers.openai.com/codex (plugins, plugins/build, changelog), Codex CLI v0.139.0.

## Reference map

| When you need… | Read first |
|---|---|
| Plugin layout, every plugin.json field, component pointers, bundled hooks/MCP/apps | `references/plugin-format.md` |
| marketplace.json schema, repo vs personal marketplaces, sources, install policies, CLI/TUI management, curated first-party plugins | `references/marketplaces.md` |

## The shape in 30 seconds

```
my-plugin/
├── .codex-plugin/
│   └── plugin.json        # the ONLY file that belongs in .codex-plugin/
├── skills/
│   └── my-skill/SKILL.md
├── hooks/hooks.json
├── .mcp.json
├── .app.json
└── assets/
```

`plugin.json` requires `name`, `version`, `description`, and points at components via relative paths that **must start with `./`** (`skills`, `mcpServers`, `apps`, `hooks`). Optional metadata: `author`, `license`, `displayName`, `category`, `brandColor`, `screenshots`. Full field table in `references/plugin-format.md`.

## Decision rules

### Plugin, or bare skills directory?

Skills already work standalone from `.agents/skills/` (repo) or `~/.agents/skills/` (personal) — no plugin needed. Build a plugin when any of these hold:

- You ship **more than skills** — hooks, an MCP server, or an app/connector config that must travel together.
- You need **versioned distribution** — a marketplace entry carries a version and an install policy; a loose skills dir does not.
- You want **per-plugin enable/disable** — users can switch a whole plugin off with one `config.toml` line instead of disabling skills one by one.
- You're targeting **team distribution** — a repo marketplace (`$REPO_ROOT/.agents/plugins/marketplace.json`) auto-offers plugins to everyone in the repo.

If it's one or two skills for yourself, skip the plugin; drop them in `~/.agents/skills/`.

### Repo marketplace or personal marketplace?

| Audience | Put marketplace.json at | Typical source |
|---|---|---|
| Everyone working in this repo | `$REPO_ROOT/.agents/plugins/marketplace.json` | `local` with a relative `path` |
| Just you, across all projects | `~/.agents/plugins/marketplace.json` | `local` or `git-subdir` |
| Other teams / the public | a git repo they add via `codex marketplace add` | `git-subdir` (URL + path) |

OpenAI's public **Plugin Directory is "coming soon"** as of June 2026 — do not design distribution around it yet. Curated first-party plugins already exist (Codex Security, Gmail, Google Drive, Slack, Sites) and are a good reference for manifest style.

### What install policy should the marketplace entry declare?

Each marketplace entry can carry a `policy` object: `installation` (e.g. `"AVAILABLE"` — offered, user opts in) and `authentication` (e.g. `"ON_INSTALL"` — auth flow runs at install time, the right choice for plugins bundling MCP servers that need credentials). Set `authentication: "ON_INSTALL"` whenever the plugin ships an MCP server with OAuth or a bearer token; otherwise users hit auth errors mid-task instead of at install.

### How do users manage the plugin once installed?

- **TUI**: the `/plugins` browser lists, installs, enables, disables.
- **CLI**: `codex marketplace add <url-or-path>`, plus `codex plugin …` subcommands (`--json` supported since v0.137–0.138 for scripting).
- **config.toml**: per-plugin disable without uninstalling:

```toml
[plugins."gmail@openai-curated"]
enabled = false
```

The key is `name@marketplace`. Document this in your plugin's README — it's the answer to "your plugin is firing too often".

## Deterministic gate

Before shipping, run this plugin's validator against the package:

```bash
bash scripts/validate.sh path/to/plugin --json | jq .
```

It checks (among other things): `.codex-plugin/plugin.json` exists, parses, and has a `name`; every component pointer starts with `./` and resolves to a real path; bundled `skills/*/SKILL.md` frontmatter carries `name` + `description`; bundled `hooks/hooks.json` parses and uses known event names. Findings come back on the shared JSON contract — fix `error`s, weigh `warn`s.

## Anti-patterns this skill catches

- Components placed inside `.codex-plugin/` — only `plugin.json` belongs there (same trap as Claude Code's `.claude-plugin/`).
- Component pointers written as bare paths (`"skills/foo"`) instead of `./`-prefixed relative paths — Codex requires the `./` prefix.
- A Claude Code `.claude-plugin/plugin.json` copied verbatim — Codex reads `.codex-plugin/plugin.json` with its own field set.
- Distribution plans that assume the public Plugin Directory exists — it's "coming soon"; ship a git marketplace today.
- MCP-bundling plugins without `authentication: "ON_INSTALL"` in their marketplace policy — auth fails surface mid-task.
- Telling users to uninstall to silence a plugin — `[plugins."name@marketplace"] enabled = false` is the supported toggle.

## Sources

- OpenAI, *Codex plugins* — bundle contents, `.codex-plugin/plugin.json`, management surfaces ([developers.openai.com/codex/plugins](https://developers.openai.com/codex/plugins)). Verified 2026-06-09 (Codex CLI v0.139.0).
- OpenAI, *Build a Codex plugin* — manifest fields, component pointers, marketplace.json schema, sources, policies ([developers.openai.com/codex/plugins/build](https://developers.openai.com/codex/plugins/build)). Verified 2026-06-09.
- OpenAI, *Codex changelog* — plugins GA ~v0.117 (Apr 2026), `--json` for plugin/marketplace commands in v0.137–0.138 ([developers.openai.com/codex/changelog](https://developers.openai.com/codex/changelog)). Verified 2026-06-09.

When upstream behavior changes, update the references — not this SKILL.md.
