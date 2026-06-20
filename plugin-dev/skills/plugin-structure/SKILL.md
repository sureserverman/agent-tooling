---
name: plugin-structure
description: Use when laying out a Claude Code plugin correctly. Triggers on "what goes in .claude-plugin/", "plugin.json schema", "marketplace.json", "where do hooks live", "CLAUDE_PLUGIN_ROOT".
---

# plugin-structure

Decision rules for laying out a Claude Code plugin correctly: what goes where, which fields the manifest requires, and how the runtime discovers each component.

## Reference map

| When you need… | Read first |
|---|---|
| Full plugin.json field list with examples | `references/manifest.md` |
| Per-component discovery rules and validity criteria | `references/discovery.md` |

## Directory layout

A plugin is a directory. The only required subdirectory is `.claude-plugin/`, which holds exactly one file: `plugin.json`. Every other component lives at the **plugin root**, not inside `.claude-plugin/`.

```
my-plugin/
├── .claude-plugin/
│   └── plugin.json          ← manifest; ONLY file here
├── skills/
│   └── <name>/
│       └── SKILL.md
├── commands/
│   └── <name>.md
├── agents/
│   └── <name>.md
├── hooks/
│   └── hooks.json
├── monitors/
│   └── monitors.json        ← experimental (v2.1.105+), needs experimental.monitors
├── output-styles/
│   └── <name>.md
├── themes/                  ← experimental, needs experimental.themes
├── bin/                     ← added to Bash PATH while plugin active
├── settings.json            ← only `agent` + `subagentStatusLine` keys honored
├── .mcp.json                ← plugin root; manual config, not auto-discovered
├── .lsp.json                ← plugin root
└── README.md
```

A `CLAUDE.md` at the plugin root is **not** loaded — use skills or a `SessionStart` hook instead.

Also valid since v2.1.157: any folder under `~/.claude/skills/` or `<cwd>/.claude/skills/` with a `.claude-plugin/plugin.json` loads in place as `<name>@skills-dir`, no marketplace needed; a single root-level `SKILL.md` plugin works too (v2.1.142+). Scaffold with `claude plugin init <name> [--with skills agents hooks mcp lsp output-style channel]`; check with `claude plugin validate` and `claude plugin details` (token-cost projection).

## Manifest fields (`plugin.json`)

**Required** — only one field. (The manifest itself is optional; always ship it anyway.)

| Field | Rules |
|---|---|
| `name` | kebab-case; becomes the skill namespace prefix (e.g. `my-plugin:skill-name`) |

**Optional**

| Field | Notes |
|---|---|
| `description` | One sentence; shown in marketplace and `/plugin list`. Always set for published plugins. |
| `displayName` | UI name (v2.1.143+) |
| `version` | Semver. Resolution chain: plugin.json → marketplace entry → git SHA → `"unknown"`. Set explicitly for any stable release. |
| `author` | `{name, email, url}` |
| `homepage`, `repository` | URLs |
| `license` | SPDX identifier, e.g. `"MIT"` |
| `keywords` | Array of strings |
| `defaultEnabled` | `false` = installs disabled (v2.1.154+) |
| `skills` | Explicit skill paths — **adds to** default `skills/` discovery |
| `commands`, `agents`, `outputStyles` | **Replace** the default directories — list the default explicitly if you still want it |
| `hooks`, `mcpServers`, `lspServers` | string \| array \| inline object; defaults `./hooks/hooks.json`, `./.mcp.json`, `./.lsp.json` |
| `experimental` | `{themes, monitors}` opt-in flags |
| `userConfig` | User options: `type` (`string`\|`number`\|`boolean`\|`directory`\|`file`), `title`, `description`, `sensitive` (keychain), `required`, `default`, `multiple`, `min`/`max`. Substituted via `${user_config.*}`; exported as `CLAUDE_PLUGIN_OPTION_<KEY>` |
| `channels` | `[{server, userConfig}]`; `server` must match an `mcpServers` key |
| `dependencies` | `[{name, version}]` semver ranges; clean up with `claude plugin prune` |
| `$schema` | JSON Schema URL for editor validation |

Minimal valid manifest:
```json
{
  "name": "my-plugin",
  "description": "Does something useful."
}
```

## Component discovery

| Component | Path | Format | Discovery |
|---|---|---|---|
| Skills | `skills/<name>/SKILL.md` | Markdown + YAML frontmatter | Auto |
| Commands | `commands/<name>.md` | Markdown + YAML frontmatter | Auto |
| Agents | `agents/<name>.md` | Markdown + YAML frontmatter | Auto |
| Hooks | `hooks/hooks.json` | JSON (one file per plugin) | Auto |
| MCP servers | `.mcp.json` | JSON, plugin root | **Manual only** |
| LSP servers | `.lsp.json` | JSON; `command` + `extensionToLanguage` required | Auto |
| Monitors | `monitors/monitors.json` | JSON array; `name`/`command`/`description` required | Auto (experimental; interactive CLI only, unsandboxed) |
| Output styles | `output-styles/<name>.md` | Markdown | Auto |
| Themes | `themes/` | — | Auto (experimental); `custom:<plugin>:<slug>` |
| Executables | `bin/` | Any executable file | Auto (Bash PATH injection) |

MCP servers are the only component that requires explicit user configuration — they are never auto-discovered because they carry connection credentials.

## Environment variables available to hooks and commands

| Variable | Value |
|---|---|
| `${CLAUDE_PLUGIN_ROOT}` | Absolute path to the plugin install directory. Use for all bundled-asset references. **Changes on plugin update.** |
| `${CLAUDE_PLUGIN_DATA}` | `~/.claude/plugins/data/{id}/` — auto-created, survives updates; deleted on last-scope uninstall unless `--keep-data`. |
| `${CLAUDE_PROJECT_DIR}` | Current project root at invocation time. |
| `CLAUDE_ENV_FILE` | Path where `SessionStart`/`Setup`/`CwdChanged`/`FileChanged` hooks can write `KEY=VALUE` lines for session-persistent env vars. |
| `CLAUDE_PLUGIN_OPTION_<KEY>` | One per `userConfig` key, exported to hooks and commands. |

Always use `${CLAUDE_PLUGIN_ROOT}` rather than a relative path when referencing bundled files from a hook or command.

## Marketplace publishing

Add a `marketplace.json` in the marketplace repository's `.claude-plugin/`. Top-level required fields: `name`, `owner.name`, `plugins[]`; optional `metadata.pluginRoot` sets the base dir for relative sources.

```json
{
  "name": "my-marketplace",
  "owner": { "name": "You" },
  "plugins": [
    {
      "name": "my-plugin",
      "source": { "source": "github", "repo": "you/my-plugin" },
      "description": "One sentence.",
      "version": "1.2.0",
      "category": "development",
      "tags": ["rust", "linting", "refactor", "cli"]
    }
  ]
}
```

Entry `source` types: relative path, `github`, `url`, `git-subdir` (sparse monorepo clone), `npm` — details in `references/discovery.md`. A full 40-char `sha` wins over `ref`.

Valid categories: `development`, `languages`, `security`, `productivity`, `database`, `deployment`, `monitoring`, `design`, `learning`.

Tags: lowercase, 4–8, mix technology names with capability words.

Install flow: `/plugin marketplace add <repo>` then `/plugin install <plugin>@<marketplace>`. Plugins cache to `~/.claude/plugins/cache` (orphaned versions kept 7 days). Marketplace names impersonating official ones (`claude-code-marketplace`, `anthropic-plugins`, `agent-skills`, …) are reserved/blocked; enterprises can constrain installs via `pluginSuggestionMarketplaces`, `strictKnownMarketplaces`, and `blockedMarketplaces` managed settings.

## Anti-patterns

**Wrong location for components.** Only `plugin.json` belongs inside `.claude-plugin/`. Placing `commands/`, `agents/`, `skills/`, `hooks/`, `.mcp.json`, or `.lsp.json` inside `.claude-plugin/` means they are never discovered.

**Relative paths in hook commands.** A hook like `./bin/check.sh` breaks when the plugin is installed at a different path. Use `${CLAUDE_PLUGIN_ROOT}/bin/check.sh`.

**Omitting `version` in stable releases.** Without an explicit semver version the runtime falls back through marketplace version → git commit SHA → `"unknown"`. Users cannot pin or reproduce the version. Set `"version"` before any public release.

**Missing README.** The README is the first thing users open after installing. Always include one at the plugin root.

**Skill `name:` mismatches with command wrapper name.** The `name` field in `SKILL.md` frontmatter becomes the internal skill ID. If it diverges from the corresponding command wrapper name, the skill appears twice in autocomplete. Keep them identical.

## Targeting Cowork? Distribution differs

The plugin **format** is the same in Claude Code and Claude Cowork (same `plugin.json`, same skills / agents / commands directories, same discovery rules). What changes is **how users install** (UI-only: official catalog, zip upload, marketplace by URL, org private marketplaces) and **which components run** (skills / connectors / agents / hooks only — no local stdio MCP, LSP, monitors, themes, or bin/).

For Cowork distribution patterns, package limits, and the component-support matrix, see the `cowork-dev` sibling plugin (`cowork-plugin-development` skill). The structure rules above still apply; only the install flow and platform support differ.

## References

- https://code.claude.com/docs/en/plugins.md
- https://code.claude.com/docs/en/plugins-reference.md (verified 2026-06-09, v2.1.170)
- https://code.claude.com/docs/en/plugin-marketplaces.md (verified 2026-06-09)
- https://github.com/anthropics/claude-plugins-official
