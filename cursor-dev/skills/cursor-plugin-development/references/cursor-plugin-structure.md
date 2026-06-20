# Cursor plugin structure (verified 2026-06-09, Cursor 3.7)

## What a plugin bundles

A Cursor plugin is one installable unit carrying any mix of the editor's
extension surfaces:

| Component | Directory in the plugin | Runtime behavior |
|---|---|---|
| Rules | `rules/*.mdc` | Injected per their type (Always / Intelligent / Specific Files / Manual) — see the `cursor-rules-and-skills` skill |
| Skills | `skills/<name>/SKILL.md` | agentskills.io-standard skills, model-invoked or slash-invoked |
| Subagents | `agents/*.md` | Specialized agents the main agent can delegate to |
| Commands | `commands/*.md` | Legacy explicit-invocation prompts (soft-deprecated in favor of skills with `disable-model-invocation: true`) |
| Hooks | `hooks/` (hooks.json) | Lifecycle event handlers — see the `cursor-hooks-and-agents` skill |
| MCP servers | root `mcp.json` | Servers configured for every install of the plugin |

A plugin needs at least one component to be useful, but none are individually
required.

## The manifest: `.cursor-plugin/plugin.json`

Lives in a `.cursor-plugin/` directory at the plugin root. Only **`name`** is
required. Recognized descriptive fields:

```json
{
  "name": "my-plugin",
  "description": "What this plugin does, third person, one or two sentences.",
  "version": "0.1.0",
  "author": { "name": "Your Name", "email": "you@example.com", "url": "https://example.com" },
  "homepage": "https://github.com/you/my-plugin",
  "repository": "https://github.com/you/my-plugin",
  "license": "MIT",
  "keywords": ["topic", "topic"]
}
```

Rules of thumb:

- `name`: kebab-case, matches the plugin directory name. This is the identity
  the marketplace and Team Marketplaces key on.
- `version`: semver. Team Marketplaces auto-refresh from the repo, so bump it
  on every meaningful change to make rollouts traceable.
- For anything published, fill `description`, `author`, `license`,
  `repository` — the marketplace listing renders them, and the manual review
  expects them.

## Canonical layout

```
my-plugin/
├── .cursor-plugin/
│   └── plugin.json          # manifest — the ONLY thing in .cursor-plugin/
├── rules/
│   └── style.mdc            # .mdc only — .md is silently ignored
├── skills/
│   └── deploy-check/
│       ├── SKILL.md         # frontmatter name MUST equal "deploy-check"
│       └── references/…
├── agents/
│   └── reviewer.md
├── commands/                # legacy; prefer skills with disable-model-invocation
│   └── changelog.md
├── hooks/
│   └── hooks.json           # {"version": 1, "hooks": {...}} — camelCase events
├── mcp.json                 # MCP servers shipped with the plugin (plugin root)
├── README.md
└── LICENSE                  # required in practice: marketplace plugins must be open source
```

Components live at the plugin **root**, not inside `.cursor-plugin/`. The
manifest directory holds the manifest (and, at a multi-plugin repo root,
`marketplace.json`) — nothing else.

## Multi-plugin repos: `marketplace.json`

One repo can ship several plugins. Put `.cursor-plugin/marketplace.json` at
the **repo root** describing the bundle, with each member plugin in its own
subdirectory carrying its own `.cursor-plugin/plugin.json`:

```
plugins-repo/
├── .cursor-plugin/
│   └── marketplace.json
├── frontend-conventions/
│   ├── .cursor-plugin/plugin.json
│   └── rules/…
└── release-tools/
    ├── .cursor-plugin/plugin.json
    └── skills/…
```

```json
{
  "name": "acme-plugins",
  "plugins": [
    { "name": "frontend-conventions", "source": "./frontend-conventions" },
    { "name": "release-tools", "source": "./release-tools" }
  ]
}
```

This is the shape Team Marketplaces consume from a registered GitHub repo, and
the shape of github.com/cursor/plugins (the ~13 official MIT plugins) — the
best living reference for layout decisions.

## Install scopes

When a user installs from the marketplace they choose:

- **Project-scoped** — active in the current workspace only; the natural scope
  for repo-convention plugins.
- **User-scoped** — active in every workspace; the natural scope for personal
  tooling.

Plugin authors don't control the scope; write the README so users pick
sensibly.

## Validation hooks (cursor-dev's deterministic lane)

`validate-cursor-artifact.sh` checks the mechanical invariants of this layout:
manifest exists/parses/has `name`; every `rules/*.mdc` has parseable YAML
frontmatter and a coherent type combo; no plain `.md` files inside `rules/`
(silently ignored by Cursor); every `skills/<dir>/SKILL.md` frontmatter `name`
equals its directory; any `hooks.json` parses, has an integer `version`, and
uses only known camelCase event names.

Source: [cursor.com/docs/plugins](https://cursor.com/docs/plugins),
[github.com/cursor/plugins](https://github.com/cursor/plugins). Verified
2026-06-09.
