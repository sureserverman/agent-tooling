# Codex marketplaces

Facts verified 2026-06-09 against [developers.openai.com/codex/plugins](https://developers.openai.com/codex/plugins) and [developers.openai.com/codex/plugins/build](https://developers.openai.com/codex/plugins/build), Codex CLI v0.139.0.

## Where marketplaces live

| Scope | Path | Audience |
|---|---|---|
| Repo | `$REPO_ROOT/.agents/plugins/marketplace.json` | Everyone working in the repo — plugins are offered automatically |
| Personal | `~/.agents/plugins/marketplace.json` | Just this user, across all projects |
| External | any git repo added via `codex marketplace add <url>` | Anyone you share the URL with |

The public **Plugin Directory** (an OpenAI-hosted catalog) is **"coming soon"** as of June 2026. Until it ships, distribution is git URLs and local paths.

## marketplace.json schema

```json
{
  "name": "team-tools",
  "plugins": [
    {
      "name": "release-helper",
      "source": {
        "source": "local",
        "path": "./plugins/release-helper"
      },
      "policy": {
        "installation": "AVAILABLE",
        "authentication": "ON_INSTALL"
      }
    },
    {
      "name": "shared-linter",
      "source": {
        "source": "git-subdir",
        "url": "https://github.com/acme/codex-plugins",
        "path": "plugins/shared-linter"
      }
    }
  ]
}
```

Top level: `name` (marketplace identifier) + `plugins` array.

### Per-plugin entry

| Field | Meaning |
|---|---|
| `name` | Must match the plugin's `plugin.json` name |
| `source` | Where to fetch the plugin from (see below) |
| `policy` | Optional install/auth behavior |

### Sources

| `source.source` | Extra fields | Use for |
|---|---|---|
| `local` | `path` (relative to the marketplace.json) | Plugins vendored in the same repo |
| `git-subdir` | `url` + `path` (subdirectory within the repo) | Plugins hosted in another git repo |

### Policy

| Key | Example value | Meaning |
|---|---|---|
| `installation` | `"AVAILABLE"` | Offered to users; they opt in. |
| `authentication` | `"ON_INSTALL"` | Run the plugin's auth flow (e.g. MCP OAuth) when the user installs, not on first use |

Use `"ON_INSTALL"` for any plugin bundling an MCP server that needs credentials — otherwise the first task that touches the server stalls on auth.

## Managing plugins and marketplaces

| Surface | What it does |
|---|---|
| `/plugins` (TUI) | Browse, install, enable, disable plugins from known marketplaces |
| `codex marketplace add <url-or-path>` | Register an external marketplace |
| `codex plugin …` / `codex marketplace …` | Scripted management; `--json` output since v0.137–0.138 |
| config.toml | Per-plugin kill switch (below) |

### Per-plugin disable

Keyed `name@marketplace` in config.toml:

```toml
[plugins."gmail@openai-curated"]
enabled = false
```

This disables the plugin's skills, hooks, and MCP servers without uninstalling.

## Curated first-party plugins

OpenAI ships curated plugins (the `openai-curated` marketplace) — as of June 2026:

- **Codex Security** — security review workflows
- **Gmail**
- **Google Drive**
- **Slack**
- **Sites**

These are useful as reference implementations: real manifests, real `ON_INSTALL` auth policies, real connector configs.

## Distribution recipes

### Team plugin inside the product repo

1. Put the plugin at `plugins/<name>/` in the repo.
2. Add `$REPO_ROOT/.agents/plugins/marketplace.json` with a `local` source `./plugins/<name>` (the `./` prefix is required, same as manifest pointers).
3. Everyone in the repo sees it offered; `installation: "AVAILABLE"` keeps it opt-in.

### Public plugin

1. Host a repo with `plugins/<name>/` and a root-level marketplace.json listing it via `git-subdir` (or `local` if the marketplace.json sits in the same repo).
2. Users run `codex marketplace add https://github.com/you/your-plugins`.
3. They install via `/plugins`.

### Personal plugin collection

Keep a `~/.agents/plugins/marketplace.json` pointing at local checkouts (`local` sources with absolute-ish relative paths) — handy for dogfooding before publishing.
