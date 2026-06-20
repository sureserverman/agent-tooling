# plugin.json — Full Field Reference

Every field the Claude Code plugin runtime (v2.1.170) reads from `plugin.json`. The file lives at `.claude-plugin/plugin.json` inside the plugin directory. The manifest itself is **optional** — a plugin without one takes its name from the directory — but always ship one for anything published.

## Contents

- [Required fields](#required-fields) — `name` (the only required field)
- [Optional fields](#optional-fields) — `$schema`, `displayName`, `version`, `description`, `author`, `homepage`, `repository`, `license`, `keywords`, `defaultEnabled`, component paths, `experimental`, `userConfig`, `channels`, `dependencies`
- [Complete example](#complete-example)
- [marketplace.json — Full Schema](#marketplacejson--full-schema)
  - [Top-level fields](#top-level-fields)
  - [Plugin entry fields](#plugin-entry-fields)
  - [Valid categories](#valid-categories)
  - [Tag guidance](#tag-guidance)
  - [Governance](#governance)

## Required fields

### `name`

The **only** required field.

Type: string  
Format: kebab-case  
Constraints: must be unique within any marketplace it is published to; becomes the namespace prefix for all skills (`<name>:<skill-name>`).

```json
"name": "rust-dev"
```

## Optional fields

### `$schema`

Type: string (URL)  
Points at the published plugin.json JSON Schema for editor validation/completion.

### `displayName`

Type: string (v2.1.143+)  
Human-readable name shown in UI listings; `name` stays the machine identifier.

### `description`

Type: string  
One sentence. Shown in `/plugin list`, marketplace listings, and the install confirmation dialog. Optional per the schema, but always set it for published plugins.

```json
"description": "Idiomatic Rust authoring with skills, subagent, and slash commands."
```

### `version`

Type: string  
Format: semver (`MAJOR.MINOR.PATCH`)  
Resolution chain when omitted: plugin.json `version` → marketplace entry `version` → git commit SHA → `"unknown"`.

Set explicitly for any release that users will pin or reproduce. The fallbacks are adequate for local development but not for published plugins.

```json
"version": "1.4.2"
```

### `author`

Type: object

| Subfield | Type | Notes |
|---|---|---|
| `name` | string | Display name |
| `email` | string | Contact address |
| `url` | string | Author website |

```json
"author": {
  "name": "Jane Developer",
  "email": "jane@example.com"
}
```

### `homepage`

Type: string (URL)  
Linked from marketplace listings and `/plugin info <name>`.

```json
"homepage": "https://example.com/my-plugin"
```

### `repository`

Type: string (URL)  
Should point to the source repository root, not a subdirectory.

```json
"repository": "https://github.com/you/my-plugin"
```

### `license`

Type: string  
Use an SPDX identifier. The runtime does not validate this, but the marketplace indexer surfaces it to users.

```json
"license": "MIT"
```

Common values: `MIT`, `Apache-2.0`, `GPL-3.0-only`, `AGPL-3.0-only`, `MPL-2.0`, `ISC`.

### `keywords`

Type: array of strings  
Used for marketplace search. No enforced limit; keep to the most specific terms.

```json
"keywords": ["rust", "cargo", "linting", "refactor"]
```

### `defaultEnabled`

Type: boolean (v2.1.154+)  
`false` installs the plugin disabled; the user opts in via `/plugin`. Use for heavyweight or niche plugins inside a bundle.

### `skills`

Type: array of strings (paths relative to plugin root)  
**Adds to** the default `skills/` auto-discovery — it does not replace it. Use to include skills outside the standard tree or control load order.

```json
"skills": [
  "skills/rust-coding/SKILL.md",
  "extra/special/SKILL.md"
]
```

### `commands`, `agents`, `outputStyles`

Type: string or array of path strings  
Unlike `skills`, these **replace** the default directories (`./commands`, `./agents`, `./output-styles`). If you set `"commands": ["./extra-commands"]`, the default `./commands` is no longer scanned — list it explicitly if you still want it.

### `hooks`, `mcpServers`, `lspServers`

Type: string (path) | array of paths | inline object  
Defaults if omitted: `./hooks/hooks.json`, `./.mcp.json`, `./.lsp.json`.

```json
"hooks": "./hooks/hooks.json",
"mcpServers": "./.mcp.json",
"lspServers": "./.lsp.json"
```

### `experimental`

Type: object  
Opt-in flags for experimental surfaces: `experimental.themes` (themes/ directory), `experimental.monitors` (monitors/monitors.json).

### `userConfig`

Type: object — declares user-facing plugin options. Each key maps to:

| Subfield | Type | Notes |
|---|---|---|
| `type` | string | `string` \| `number` \| `boolean` \| `directory` \| `file` |
| `title` | string | Label shown in the config UI |
| `description` | string | Help text |
| `sensitive` | boolean | Stored in the OS keychain, never plaintext |
| `required` | boolean | Prompted at install/enable |
| `default` | any | Default value |
| `multiple` | boolean | Accept multiple values |
| `min` / `max` | number | Bounds for `number` type |

Values are substituted anywhere in plugin config via `${user_config.<key>}` and exported to hooks/commands as `CLAUDE_PLUGIN_OPTION_<KEY>` env vars.

```json
"userConfig": {
  "api_endpoint": { "type": "string", "title": "API endpoint", "required": true },
  "api_token":    { "type": "string", "title": "API token", "sensitive": true }
}
```

### `channels`

Type: array of `{ "server": "<mcpServers key>", "userConfig": { … } }`  
Declares notification/communication channels backed by an MCP server. `server` must match a key in `mcpServers`.

### `dependencies`

Type: array of `{ "name": "<plugin>", "version": "<semver range>" }`  
Other plugins this one requires; installed alongside it. `claude plugin prune` removes dependencies no longer needed by any installed plugin.

### Path resolution rules

Every path in `plugin.json` (and bundled config) follows the same rules:

- **Relative only** — must start with `./`; absolute paths break on other machines.
- **No `..`** — paths may not escape the plugin root.
- **Forward slashes** — even authored on Windows.
- Bundled scripts referenced from hooks/MCP use the `${CLAUDE_PLUGIN_ROOT}` variable, which the runtime expands to the plugin's install directory at run time.

Common manifest errors: a `name` with spaces/underscores (must be kebab-case), an absolute or `../` path, a missing `./` prefix, or a non-semver `version` like `"1.0"` instead of `"1.0.0"`. The deterministic `validate-manifest.sh` catches all of these.

## Complete example

```json
{
  "name": "rust-dev",
  "displayName": "Rust Dev",
  "description": "Idiomatic Rust authoring with skills, subagent, and slash commands.",
  "version": "2.1.0",
  "author": {
    "name": "Jane Developer",
    "email": "jane@example.com"
  },
  "homepage": "https://example.com/rust-dev",
  "repository": "https://github.com/you/rust-dev",
  "license": "MIT",
  "keywords": ["rust", "cargo", "tokio", "clippy"],
  "skills": [
    "skills/rust-coding/SKILL.md",
    "skills/rust-expert/SKILL.md"
  ]
}
```

---

## marketplace.json — Full Schema

Lives at `.claude-plugin/marketplace.json` in the **marketplace repository** (not inside any individual plugin). One file lists all plugins the marketplace distributes.

```json
{
  "name": "my-marketplace",
  "owner": { "name": "Jane Developer" },
  "metadata": { "pluginRoot": "./plugins" },
  "plugins": [
    {
      "name": "rust-dev",
      "source": "./rust-dev",
      "description": "Idiomatic Rust authoring with skills, subagent, and slash commands.",
      "version": "2.1.0",
      "category": "languages",
      "tags": ["rust", "cargo", "linting", "refactor", "async", "tokio"]
    }
  ]
}
```

### Top-level fields

| Field | Required | Type | Notes |
|---|---|---|---|
| `name` | Yes | string | Marketplace identifier (kebab-case) |
| `owner` | Yes | object | At least `{ "name": … }` |
| `plugins` | Yes | array | Plugin entries (below) |
| `$schema` | No | string | JSON Schema URL for editor validation |
| `description` | No | string | Marketplace description |
| `version` | No | string | Pins the catalog version |
| `metadata.pluginRoot` | No | string | Base directory that relative `source` paths resolve against |
| `allowCrossMarketplaceDependenciesOn` | No | array | Allowlist of other marketplaces that plugin `dependencies` may resolve from |

### Plugin entry fields

| Field | Required | Type | Notes |
|---|---|---|---|
| `name` | Yes | string | Must match the plugin's `plugin.json` `name` |
| `source` | Yes | string \| object | Where to fetch the plugin — see source types below |
| `description` | No | string | One sentence; may differ from plugin.json for marketing copy |
| `version` | No | string | Semver; used in the version-resolution chain |
| `category` | No | string | One of the valid category values below |
| `tags` | No | array | 4–8 lowercase strings |
| `strict` | No | boolean | Fail install on validation warnings |
| `defaultEnabled` | No | boolean | Install disabled when `false` |
| `displayName` | No | string | UI name override |

A marketplace entry may also carry **any plugin-manifest field** (it overlays the plugin's own `plugin.json`).

**Source types:** relative path, `github {repo, ref?, sha?}`, `url {url, ref?, sha?}`, `git-subdir {url, path, ref?, sha?}`, `npm {package, version?, registry?}`. A full 40-char `sha` wins over `ref`. Details and examples in `discovery.md`.

### Valid categories

`development`, `languages`, `security`, `productivity`, `database`, `deployment`, `monitoring`, `design`, `learning`

### Tag guidance

Mix technology identifiers with capability words. Examples:
- `["rust", "cargo", "linting", "refactor", "async", "tokio"]`
- `["python", "typing", "mypy", "dataclasses", "testing"]`
- `["security", "audit", "sast", "secrets", "cve"]`

Avoid vague tags like `"tool"`, `"helper"`, `"utility"` — they do not aid search.

### Governance

- **Reserved names** — marketplace names like `claude-code-marketplace`, `anthropic-plugins`, `agent-skills` (and similar official-sounding names) are reserved; impersonating names are blocked.
- **Managed settings** (enterprise): `pluginSuggestionMarketplaces` (v2.1.152+, marketplaces Claude may suggest), `strictKnownMarketplaces` (only allowlisted marketplaces install), `blockedMarketplaces` (denylist; `{"source": "skills-dir"}` blocks skills-dir plugins).

## Sources

- code.claude.com/docs/en/plugins-reference (verified 2026-06-09, v2.1.170)
- code.claude.com/docs/en/plugin-marketplaces (verified 2026-06-09)
