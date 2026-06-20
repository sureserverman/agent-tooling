---
name: opencode-config-and-skills
description: Use when editing OpenCode configuration, skills, rules, MCP servers, or themes. Triggers on "opencode.json", "opencode config", "OpenCode skills", "OpenCode rules AGENTS.md", "OpenCode MCP", "opencode themes", "OpenCode instructions array", "config merge order", "OPENCODE_CONFIG".
---

# opencode-config-and-skills

Everything in OpenCode (opencode.ai terminal agent; canonical source **github.com/anomalyco/opencode**) that isn't code: **opencode.json** configuration and its 8-layer merge order, **native Agent Skills**, **rules** (AGENTS.md and the `instructions` array), **MCP servers**, and **themes**.

All facts verified 2026-06-09 against opencode.ai/docs (config, skills, rules, mcp-servers, themes), OpenCode **v1.16.x** (June 2026).

## Reference map

| When you need… | Read first |
|---|---|
| `opencode.json(c)` schema, the full merge order, `{env:}`/`{file:}` substitution, top-level key catalog, `share` vs deprecated `autoshare`, the `tui.json` split | `references/opencode-config.md` |
| Skill discovery paths (incl. `.claude/skills/` Claude Code compat), SKILL.md frontmatter constraints, on-demand loading; AGENTS.md vs CLAUDE.md fallback, the `instructions` array (globs, remote URLs) | `references/opencode-skills-and-rules.md` |
| MCP `local`/`remote` config, OAuth + Dynamic Client Registration, the context-bloat gotcha; theme file format, color values, built-ins | `references/opencode-mcp-and-themes.md` |

## Decision rules

### Where does a setting belong?

The merge order (later overrides; objects merge by key — full chain in `opencode-config.md`):

1. remote `.well-known/opencode` → 2. `~/.config/opencode/opencode.json` (global) → 3. `OPENCODE_CONFIG` path → 4. project `opencode.json` → 5. `.opencode/` dir config → 6. `OPENCODE_CONFIG_CONTENT` (inline) → 7. managed (`/etc/opencode/`, `/Library/Application Support/opencode/`) → 8. macOS MDM.

Rules of thumb: personal defaults → global; repo contracts (MCP, agents, instructions) → project `opencode.json` with `"$schema": "https://opencode.ai/config.json"`; org enforcement → managed layer (it overrides projects deliberately). Theme/TUI settings live in the newer split-out **`tui.json`** (`$schema: https://opencode.ai/tui.json`). Secrets never go in config files — use `{env:VAR}` or `{file:path}` substitution.

### Skill, rule, or instructions entry?

| Signal | Surface |
|---|---|
| On-demand capability with procedure/reference docs, loaded only when relevant | **Skill** (`.opencode/skills/<name>/SKILL.md`) |
| Always-on project orientation (build, test, conventions) | **AGENTS.md** at the repo root (`/init` scaffolds it) |
| Personal always-on guidance | global `~/.config/opencode/AGENTS.md` |
| Reuse existing rule files from other tools (Cursor rules, per-package AGENTS.md) | **`instructions` array** — paths, globs, even remote URLs |

OpenCode supports Agent Skills **natively** — community skill-loader plugins (opencode-agent-skills etc.) are obsolete. It also reads **`.claude/skills/`** (Claude Code compat) and `.agents/skills/`, walked from cwd to the worktree root plus global — existing Claude Code project skills just work. Frontmatter constraints (name regex, description length) and recent fixes in `opencode-skills-and-rules.md`.

### CLAUDE.md fallback

When **no AGENTS.md exists**, OpenCode falls back to `CLAUDE.md` (project) and `~/.claude/CLAUDE.md` (global). Disable with `OPENCODE_DISABLE_CLAUDE_CODE=1`. Don't rely on the fallback long-term — `/init` an AGENTS.md and make it canonical.

### MCP: the context-bloat gotcha

Every enabled MCP server's **tool definitions are sent with your messages and consume context** — the docs call this out, and GitHub's MCP server is the notorious example. The pattern: define servers in config, **disable them globally** (`"enabled": false`), and re-enable per agent that actually needs them. Config shapes, OAuth/DCR, and timeouts in `opencode-mcp-and-themes.md`.

## Anti-patterns this skill catches

- `"autoshare": true` — deprecated boolean; use `"share": "auto"` (`"manual"` | `"auto"` | `"disabled"`) (`opencode-autoshare-deprecated`).
- Unknown top-level keys in `opencode.json` — typos (`"agents"` for `"agent"`, `"mcps"` for `"mcp"`) are silently ignored (`opencode-config-unknown-key`).
- JSON comments in a file named `.json` — comments need the `.jsonc` extension or the parser may reject them (`opencode-config-parse`).
- Installing a skill-loader plugin in 2026 — skills are native; delete the plugin.
- Skill `name` violating `^[a-z0-9]+(-[a-z0-9]+)*$` or 1–64 chars, or a missing/oversized `description` (1–1024) — the skill won't load (`opencode-skill-frontmatter`).
- Enabling a fat MCP server globally "to have it around" — permanent context tax; disable globally, enable per agent.
- Hardcoded tokens in `mcp.environment` or `headers` — use `{env:VAR}` / `{file:path}`.
- Sourcing facts from open-code.ai or opencodedocs.com — unofficial mirrors, NOT canonical; use opencode.ai/docs.

## Sources

- OpenCode, *Config* — schema, merge order, substitution, top-level keys, share ([opencode.ai/docs/config](https://opencode.ai/docs/config)). Verified 2026-06-09.
- OpenCode, *Skills* — paths incl. `.claude/skills/`, frontmatter constraints, native loading ([opencode.ai/docs/skills](https://opencode.ai/docs/skills)). Verified 2026-06-09.
- OpenCode, *Rules* — AGENTS.md, CLAUDE.md fallback, instructions array ([opencode.ai/docs/rules](https://opencode.ai/docs/rules)). Verified 2026-06-09.
- OpenCode, *MCP servers* — local/remote, OAuth + RFC 7591 DCR, context warning ([opencode.ai/docs/mcp-servers](https://opencode.ai/docs/mcp-servers)). Verified 2026-06-09.
- OpenCode, *Themes* — file format, color values, built-ins ([opencode.ai/docs/themes](https://opencode.ai/docs/themes)). Verified 2026-06-09.

When upstream behavior changes, update the references — not this SKILL.md.
