# opencode.json — schema, merge order, substitution (verified 2026-06-09, OpenCode v1.16)

## Files

- **`opencode.json`** (or **`opencode.jsonc`** — JSONC `//` comments only with
  the `.jsonc` extension) at the project root or `~/.config/opencode/`.
  Always set `"$schema": "https://opencode.ai/config.json"` for editor
  validation.
- **`tui.json`** (`"$schema": "https://opencode.ai/tui.json"`) — the newer
  split-out file for theme/TUI presentation settings. Keep behavior in
  `opencode.json`, presentation in `tui.json`.

## Merge order

Layers load in this order; **later overrides earlier, and object keys merge**
(so a project can add one MCP server without clobbering global ones):

1. Remote `.well-known/opencode` (org-served defaults)
2. Global `~/.config/opencode/opencode.json`
3. File named by `OPENCODE_CONFIG` (env var, path)
4. Project `opencode.json` (worktree root)
5. `.opencode/` directory config
6. `OPENCODE_CONFIG_CONTENT` (env var, inline JSON)
7. Managed: `/etc/opencode/` (Linux), `/Library/Application Support/opencode/` (macOS)
8. macOS MDM profiles

Managed/MDM layers loading *last* is the point: org policy beats project and
user settings. Debug surprising values by walking the chain top to bottom.

## Variable substitution

Anywhere in string values:

- `{env:VAR}` — environment variable (empty string if unset)
- `{file:path}` — file contents (relative paths resolve from the config file)

```json
{
  "provider": {
    "anthropic": { "options": { "apiKey": "{env:ANTHROPIC_API_KEY}" } }
  },
  "instructions": ["{file:./docs/style.md}"]
}
```

This is the sanctioned way to keep secrets out of committed config.

## Top-level keys

| Key | Purpose |
|---|---|
| `model` | default model, `provider/model-id` |
| `small_model` | cheap model for summarization/titles |
| `provider` | provider config + credentials (with substitution) |
| `agent` | agents (see `opencode-agents-and-commands`) |
| `command` | commands (JSON form) |
| `permission` | global tool permissions (`ask`/`allow`/`deny`, bash glob maps) |
| `tools` | global tool enable/disable (booleans; per-agent use is the deprecated path) |
| `mcp` | MCP servers (see `opencode-mcp-and-themes.md`) |
| `plugin` | npm plugin packages, auto-installed via Bun |
| `instructions` | extra rule files: paths, globs, remote URLs |
| `formatter` | code formatter config |
| `lsp` | language server config |
| `shell` | shell to use for bash |
| `server` | server host/port settings |
| `share` | `"manual"` \| `"auto"` \| `"disabled"` — **replaces deprecated `autoshare` boolean** |
| `snapshot` | workspace snapshotting on/off |
| `autoupdate` | self-update behavior |

Unknown keys are **silently ignored** — a typo (`"agents"`, `"mcps"`,
`"plugins"` as a config key) just doesn't work, with no warning.
opencode-dev's validator flags unknown top-level keys
(`opencode-config-unknown-key`) and `autoshare`
(`opencode-autoshare-deprecated`).

## `share` vs `autoshare`

Old: `"autoshare": true`. Current: `"share": "auto"`. Values:

- `"manual"` — share only via the explicit share command (default)
- `"auto"` — every session gets a share link
- `"disabled"` — sharing off entirely (org-managed layers commonly pin this)

## Checklist

1. `$schema` set; extension matches content (`.jsonc` iff comments).
2. Right layer for the setting (personal → global, repo → project,
   policy → managed).
3. Secrets via `{env:}`/`{file:}` only.
4. No `autoshare`; no unknown top-level keys.
5. Run opencode-dev's `scripts/validate.sh` — parse
   (`opencode-config-parse`), unknown keys, deprecated flags.

Source: [opencode.ai/docs/config](https://opencode.ai/docs/config).
Verified 2026-06-09.
