# Component Discovery Reference

How the Claude Code plugin runtime finds and validates each component type. "Auto-discovered" means the runtime scans the well-known path without any manifest entry. "Manual" means the user must configure the component explicitly.

## Contents

- [Discovery summary](#discovery-summary)
- [Skills — `skills/<name>/SKILL.md`](#skills--skillsnameskillmd)
- [Commands — `commands/<name>.md`](#commands--commandsnamemd)
- [Agents — `agents/<name>.md`](#agents--agentsnamemd)
- [Hooks — `hooks/hooks.json`](#hooks--hookshooksjson)
- [MCP Servers — `.mcp.json` (manual only)](#mcp-servers--mcpjson-manual-only)
- [LSP Servers — `.lsp.json`](#lsp-servers--lspjson)
- [Monitors — `monitors/monitors.json`](#monitors--monitorsmonitorsjson)
- [Executables — `bin/`](#executables--bin)
- [Other surfaces](#other-surfaces) — themes/, output-styles/, settings.json
- [Plugin data directory](#plugin-data-directory)
- [How plugins themselves are discovered](#how-plugins-themselves-are-discovered) — marketplace source types (incl. git-subdir), skills-dir plugins, cache
- [CLI workflow](#cli-workflow)

## Discovery summary

| Component | Scan path | Auto? | Single or multiple |
|---|---|---|---|
| Skills | `skills/*/SKILL.md` | Yes | One per subdirectory |
| Commands | `commands/*.md` | Yes | One per file |
| Agents | `agents/*.md` | Yes | One per file |
| Hooks | `hooks/hooks.json` | Yes | One file; array inside |
| MCP servers | `.mcp.json` | **No** | One file; map inside |
| LSP servers | `.lsp.json` | Yes | One file; map inside |
| Monitors | `monitors/monitors.json` | Yes (experimental, v2.1.105+) | One file; array inside |
| Executables | `bin/*` | Yes | All files in dir |
| Output styles | `output-styles/*.md` | Yes | One per file |
| Themes | `themes/` | Yes (experimental) | Registered as `custom:<plugin>:<slug>` |
| Settings | `settings.json` (plugin root) | Yes | Only `agent` + `subagentStatusLine` keys |

A `CLAUDE.md` at the plugin root is **not** loaded — plugins cannot inject instructions that way; use skills or `SessionStart` hooks.

---

## Skills — `skills/<name>/SKILL.md`

**Valid when:**
- File exists at exactly `skills/<name>/SKILL.md` (the directory name is the local identifier, not the frontmatter `name`).
- File opens with a `---`-delimited YAML frontmatter block.
- Frontmatter contains at least `name` (string) and `description` (string).
- `name` in frontmatter becomes the full skill ID as `<plugin-name>:<name>`.

**Discovery behavior:**
The runtime walks `skills/`, treating each immediate subdirectory as a candidate. It reads `SKILL.md` from the subdirectory root. Deeply nested skill files (e.g. `skills/foo/bar/SKILL.md`) are not discovered.

**Override with `skills` manifest field:**
If `plugin.json` lists explicit paths in `"skills"`, those are loaded in order first. Any `skills/*/SKILL.md` not already listed is then auto-discovered and appended.

---

## Commands — `commands/<name>.md`

**Valid when:**
- File matches `commands/<name>.md` at the plugin root level (no subdirectories).
- File has YAML frontmatter with at least a `name` field.
- The `name` field matches the filename stem — mismatches cause duplicate autocomplete entries.

**Command name convention:** the `/` prefix is added by the runtime. A file `commands/rust-review.md` with `name: rust-review` registers as `/rust-review`.

---

## Agents — `agents/<name>.md`

**Valid when:**
- File matches `agents/<name>.md` at the plugin root level.
- File has YAML frontmatter. Required fields vary by host (Claude Code, Cursor, Codex); at minimum `name` and `description` are expected by Claude Code.

**Multi-host note:** If the plugin must target multiple hosts, use subdirectories per host (`agents/claude-code/<name>.md`, `agents/cursor/<name>.md`) and list them explicitly in the manifest `skills` field — auto-discovery only scans the flat `agents/` directory.

---

## Hooks — `hooks/hooks.json`

**Valid when:**
- File exists at `hooks/hooks.json`.
- Content is valid JSON.
- Top-level structure is an object keyed by hook event name.

Typical structure:
```json
{
  "SessionStart": [
    { "command": "${CLAUDE_PLUGIN_ROOT}/bin/init.sh" }
  ],
  "PostToolUse": [
    { "command": "${CLAUDE_PLUGIN_ROOT}/bin/post-tool.sh", "tools": ["Bash"] }
  ]
}
```

**Interpreter note:** Hook commands run under `/bin/sh`, not `/bin/bash`. Use `#!/bin/bash` as the first line of any hook script that uses bash-specific syntax, or write the hook as a separate script file.

32 recognized events as of v2.1.170 (`SessionStart`, `Setup`, `PreToolUse`, `PostToolUse`, `Stop`, `PreCompact`/`PostCompact`, `WorktreeCreate`/`WorktreeRemove`, …) — full catalogue with input/output schemas lives in the `hook-development` skill's `references/events.md`.

---

## MCP Servers — `.mcp.json` (manual only)

**Not auto-discovered.** The user must run `/mcp add` or edit their Claude Code settings to register an MCP server. The `.mcp.json` file at the plugin root is a template/hint; it is not loaded automatically.

Reason: MCP servers carry connection credentials and may have side effects. The runtime requires explicit user consent for each server.

Typical file structure (for documentation purposes):
```json
{
  "servers": {
    "my-server": {
      "command": "${CLAUDE_PLUGIN_ROOT}/bin/mcp-server",
      "args": [],
      "env": {}
    }
  }
}
```

---

## LSP Servers — `.lsp.json`

**Valid when:**
- File exists at `.lsp.json` at the plugin root.
- Each server entry has the two required fields: `command` and `extensionToLanguage`.

Each entry names a language server the plugin provides. The runtime starts it when a file matching a registered extension is opened. `transport` is `stdio` (default) or `socket`.

```json
{
  "my-lsp": {
    "command": "${CLAUDE_PLUGIN_ROOT}/bin/my-lsp",
    "transport": "stdio",
    "extensionToLanguage": { ".myext": "mylang" }
  }
}
```

The official marketplace ships LSP plugins for pyright, typescript, and rust-analyzer — prefer installing those over re-wrapping the same servers.

---

## Monitors — `monitors/monitors.json`

**Experimental (v2.1.105+); requires `experimental.monitors` in plugin.json. Interactive CLI only, and monitor commands run unsandboxed.**

**Valid when:**
- File exists at `monitors/monitors.json`.
- Content is a valid JSON array of monitor objects.
- Each object has the three required fields: `name`, `command`, `description`.

Monitors are background watchers; each stdout line the command emits becomes a notification in the session. Optional `when` controls lifetime: `"always"` or `"on-skill-invoke:<skill>"`.

```json
[
  {
    "name": "file-watcher",
    "description": "Surfaces build-artifact changes",
    "command": "${CLAUDE_PLUGIN_ROOT}/bin/watch.sh",
    "when": "always"
  }
]
```

---

## Executables — `bin/`

**Valid when:**
- File exists anywhere directly under `bin/` (not in subdirectories).
- File has the executable bit set (`chmod +x`).

The entire `bin/` directory is prepended to the Bash `PATH` environment variable for the duration of the session while the plugin is active. This makes plugin-bundled tools available to hooks, commands, and any Bash tool calls without absolute paths — though within hook scripts you should still use `${CLAUDE_PLUGIN_ROOT}/bin/<name>` for clarity.

---

## Other surfaces

- **`output-styles/*.md`** — output styles auto-discovered like commands; override dir with the `outputStyles` manifest field (which **replaces** the default).
- **`themes/`** — experimental (requires `experimental.themes`); each theme registers as `custom:<plugin>:<slug>`.
- **`settings.json` at the plugin root** — only two keys are honored: `agent` and `subagentStatusLine`. Anything else is ignored.

---

## Plugin data directory

`${CLAUDE_PLUGIN_DATA}` resolves to `~/.claude/plugins/data/{id}/` — auto-created on first use, survives plugin updates (unlike `${CLAUDE_PLUGIN_ROOT}`, which changes on update), and is deleted when the plugin is uninstalled from its last scope unless `--keep-data` is passed.

---

## How plugins themselves are discovered

### Marketplace entry source types

A `marketplace.json` plugin entry's `source` is one of:

| Type | Shape | Notes |
|---|---|---|
| relative path | `"./plugins/my-plugin"` | Resolved against `metadata.pluginRoot` if set |
| github | `{ "source": "github", "repo": "owner/repo", "ref"?, "sha"? }` | |
| url | `{ "source": "url", "url": "https://…/repo.git", "ref"?, "sha"? }` | Any git-cloneable URL |
| git-subdir | `{ "source": "git-subdir", "url": "owner/repo", "path": "plugins/my-plugin", "ref"?, "sha"? }` | Sparse clone of one monorepo subdirectory; `url` accepts `owner/repo` shorthand or SSH |
| npm | `{ "source": "npm", "package": "@scope/name", "version"?, "registry"? }` | |

A full 40-character `sha` always wins over `ref` when both are present.

### Skills-dir plugins (v2.1.157+)

Any folder under `~/.claude/skills/` or `<cwd>/.claude/skills/` that contains `.claude-plugin/plugin.json` loads **in place** as `<name>@skills-dir` — no marketplace needed. Single root-level `SKILL.md` plugins are also valid (v2.1.142+). Enterprises can block the whole mechanism with `blockedMarketplaces: [{"source": "skills-dir"}]`.

### Cache and symlinks

Installed plugins live in `~/.claude/plugins/cache`; orphaned versions are kept 7 days after an update. Symlink handling on install: links **within the plugin** are preserved, links **within the marketplace** are dereferenced (copied), links pointing **outside** are skipped.

---

## CLI workflow

```
claude plugin init <name> [--with skills agents hooks mcp lsp output-style channel]
claude plugin validate <dir>     # deterministic structure check
claude plugin details <plugin>   # includes token-cost projection
claude plugin tag <plugin>       # manage tags
claude plugin prune              # remove no-longer-needed dependencies
```

---

## Sources

- code.claude.com/docs/en/plugins-reference (verified 2026-06-09, v2.1.170)
- code.claude.com/docs/en/plugin-marketplaces (verified 2026-06-09)
