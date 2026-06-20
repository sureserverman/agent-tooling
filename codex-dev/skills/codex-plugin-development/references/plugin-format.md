# Codex plugin format

Facts verified 2026-06-09 against [developers.openai.com/codex/plugins](https://developers.openai.com/codex/plugins) and [developers.openai.com/codex/plugins/build](https://developers.openai.com/codex/plugins/build), Codex CLI v0.139.0.

## What a plugin bundles

A Codex plugin is a directory that packages any combination of:

| Component | Lives at | Notes |
|---|---|---|
| Skills | `skills/<name>/SKILL.md` | Standard agentskills.io skills; same files work standalone |
| Hooks | `hooks/hooks.json` | Same JSON shape as standalone hooks; see the codex-config-and-hooks skill |
| MCP servers | `.mcp.json` | stdio or streamable HTTP server definitions |
| App / connector config | `.app.json` | App and connector wiring |
| Static assets | `assets/` | Icons, screenshots, templates |

## Layout

```
my-plugin/
├── .codex-plugin/
│   └── plugin.json        # manifest — the ONLY plugin.json, and the ONLY file in .codex-plugin/
├── skills/
│   ├── first-skill/
│   │   └── SKILL.md
│   └── second-skill/
│       └── SKILL.md
├── hooks/
│   └── hooks.json
├── .mcp.json
├── .app.json
└── assets/
    └── icon.png
```

Rule: `.codex-plugin/` holds `plugin.json` and nothing else. Skills, hooks, MCP and app configs live at the plugin root, referenced from the manifest.

## plugin.json fields

### Required

| Field | Type | Notes |
|---|---|---|
| `name` | string | Plugin identifier; kebab-case by convention |
| `version` | string | Semver |
| `description` | string | What the plugin does — shown in `/plugins` and marketplace listings |

### Component pointers

Relative paths **starting with `./`**, resolved from the plugin root:

| Field | Points at | Example |
|---|---|---|
| `skills` | skill directories | `["./skills/first-skill", "./skills/second-skill"]` |
| `mcpServers` | MCP server config | `"./.mcp.json"` |
| `apps` | app/connector config | `"./.app.json"` |
| `hooks` | hooks config | `"./hooks/hooks.json"` |

A pointer that does not start with `./`, or that points at a path that does not exist, breaks installation. This is the most common hand-rolled-manifest failure; `validate-codex-artifact.sh` flags both cases.

### Optional metadata

| Field | Type | Notes |
|---|---|---|
| `author` | object/string | Attribution |
| `license` | string | SPDX identifier, e.g. `"MIT"` |
| `displayName` | string | Human-friendly name for UI listings |
| `category` | string | Marketplace grouping |
| `brandColor` | string | Accent color for UI |
| `screenshots` | array | Paths to listing screenshots (usually under `assets/`) |

### Example manifest

```json
{
  "name": "release-helper",
  "version": "1.2.0",
  "description": "Drafts release notes from merged PRs and tags the release.",
  "displayName": "Release Helper",
  "author": { "name": "platform-team" },
  "license": "MIT",
  "category": "developer-tools",
  "brandColor": "#0f766e",
  "skills": ["./skills/draft-notes", "./skills/cut-tag"],
  "hooks": "./hooks/hooks.json",
  "mcpServers": "./.mcp.json",
  "screenshots": ["./assets/listing.png"]
}
```

## How bundled components behave

- **Skills** behave exactly like skills discovered from `.agents/skills/` — they join the skill catalog, fire implicitly on description match or explicitly via `$skill-name`. Per-skill `agents/openai.yaml` sidecars work inside plugins too.
- **Hooks** in `hooks/hooks.json` join the hook resolution chain alongside user- and repo-level hooks (see codex-config-and-hooks for precedence and the trust model — plugin hooks from a marketplace your org manages can be treated as managed; others go through `/hooks` trust review).
- **MCP servers** in `.mcp.json` register like `[mcp_servers.<name>]` entries in config.toml. If they need auth, pair them with `authentication: "ON_INSTALL"` in the marketplace entry so the auth flow runs at install time.

## Enable/disable

Users disable an installed plugin without uninstalling via config.toml, keyed `name@marketplace`:

```toml
[plugins."gmail@openai-curated"]
enabled = false
```

## Version timeline (changelog)

- **~v0.117 (April 2026)** — plugins generally available.
- **v0.137–v0.138** — `codex plugin` and `codex marketplace` commands gained `--json` output for scripting.
- **v0.139 (current at verification)** — multi-agent v2 runtime rollout continues; no plugin-format changes.
