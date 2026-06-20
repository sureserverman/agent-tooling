---
name: cursor-plugin-development
description: Use when authoring or shipping a plugin for Cursor (the AI editor). Triggers on "build a Cursor plugin", "cursor-plugin manifest", ".cursor-plugin/plugin.json", "Cursor marketplace", "publish to Cursor marketplace", "Team Marketplace", "private Cursor plugins", "install a local Cursor plugin".
---

# cursor-plugin-development

Cursor gained a first-class plugin system in 2.5 (Feb 17, 2026) and a public marketplace alongside it. A Cursor plugin bundles the editor's existing extension surfaces — **rules, skills, agents, commands, MCP servers, and hooks** — into one installable unit. The format rhymes with Claude Code's plugin format but is its own thing, with its own manifest directory (`.cursor-plugin/`, not `.claude-plugin/`), its own marketplace with a manual review and a **hard open-source requirement**, and its own enterprise distribution channel (Team Marketplaces, 2.6).

All platform facts in this skill and its references were verified 2026-06-09 against cursor.com/docs, the official plugins repo, and the Cursor changelog. Current Cursor version: **3.7** (Jun 4–5, 2026).

## Reference map

| When you need… | Read first |
|---|---|
| Manifest schema, plugin directory layout, multi-plugin repos (`marketplace.json`), what each component dir does | `references/cursor-plugin-structure.md` |
| Install paths, local-dev loop (`~/.cursor/plugins/local/`), publishing to cursor.com/marketplace, Team Marketplaces, the official plugins repo | `references/cursor-plugin-distribution.md` |
| Release timeline 2.4 → 3.7, what shipped when, Agent SDK pointer | `references/cursor-version-timeline.md` |

## Decision rules

### Is a plugin the right packaging at all?

A plugin is for **distribution**. If the rules/skills/hooks only ever serve one repo, commit them directly to that repo's `.cursor/` directory — no manifest, no review, no marketplace. Reach for a plugin when:

- the same bundle should install across many projects or many people;
- you want user-scoped install (available in every workspace);
- an org should push it via a Team Marketplace.

### What goes in the manifest?

`.cursor-plugin/plugin.json` at the plugin root. Only `name` is **required**; `description`, `version`, `author`, and the other descriptive fields are optional but expected for anything published. Components live in conventional top-level directories next to `.cursor-plugin/`: `rules/`, `skills/<name>/SKILL.md`, `agents/`, `commands/`, `hooks/`, and a root `mcp.json`. Full schema and layout in `cursor-plugin-structure.md`.

One repo, several plugins? Put `.cursor-plugin/marketplace.json` at the repo root listing the member plugins. Pattern in `cursor-plugin-structure.md`.

### How do users get it?

Three channels, in order of reach (details in `cursor-plugin-distribution.md`):

1. **Marketplace** — the in-editor Marketplace panel or cursor.com/marketplace. Installs are **project-scoped or user-scoped**, the user picks.
2. **Team Marketplace** (2.6+, Teams/Enterprise) — admins register private GitHub repos in the dashboard; plugins can be **required or optional per SCIM group**, and auto-refresh from the repo within ~10 minutes via the Cursor GitHub App.
3. **Local** — drop or symlink the plugin into `~/.cursor/plugins/local/<name>` and Reload Window. This is the development loop. A hook's `workspaceOpen` event can also return `{"pluginPaths": [...]}` to inject plugin directories programmatically.

### Can it be closed-source?

Not on the public marketplace. Publishing goes through cursor.com/marketplace/publish, every submission gets **manual review**, and **all marketplace plugins must be open source**. Anthropic-style "ship a binary blob" is not an option there. If the code can't be open, distribute via a Team Marketplace (private GitHub repos are fine there) or local install.

The reference bar: Cursor maintains ~13 official plugins at github.com/cursor/plugins, all MIT — study them before inventing structure.

### Plugin or Agent SDK?

The **Cursor Agent SDK** (TypeScript/Python, Apr 2026; custom tools and stores added in 3.7) is a separate, *programmatic* surface — you drive the agent from your own code. A plugin extends the editor for interactive use; the SDK embeds the agent elsewhere. If the user says "call Cursor's agent from my CI/app/server", that's SDK territory, not this skill — point them at cursor.com/docs and stop.

### Which Cursor version can you assume?

Don't assume features beyond what the user's version ships. The timeline reference maps features to versions: subagents+skills (2.4), plugins+marketplace (2.5), Team Marketplaces+MCP Apps (2.6), agent-first UI (3.0), permissions.json + Auto-review (3.6), current 3.7. If a plugin depends on a 2.6+ feature (Team Marketplace, MCP Apps), say so in its README.

## Authoring checklist

1. Lay out the directory per `cursor-plugin-structure.md`; `name` in the manifest, kebab-case, matching the directory.
2. Write components with their own skills: rules and skills content → `cursor-rules-and-skills`; hooks, subagents, MCP → `cursor-hooks-and-agents`.
3. Gate with the deterministic lane: `bash scripts/validate.sh <plugin-dir>` (from cursor-dev) checks manifest parse/name, `.mdc` frontmatter and rule-type combos, plain-`.md` rules that Cursor silently ignores, skill `name`↔directory mismatches, and unknown hook event names.
4. Test locally via `~/.cursor/plugins/local/<name>` + Reload Window before submitting.
5. Publish: open-source the repo, submit at cursor.com/marketplace/publish, expect manual review.

## Anti-patterns this skill catches

- A manifest at `.claude-plugin/plugin.json` in a Cursor-bound plugin — Cursor reads **`.cursor-plugin/plugin.json`**. The deterministic lane flags a missing manifest (`cursor-manifest-missing`).
- Rules shipped as `rules/*.md` — Cursor only loads **`.mdc`**; plain `.md` is silently ignored (`cursor-rules-md-ignored`).
- A closed-source plugin aimed at the public marketplace — rejected; all marketplace plugins must be open source.
- Hooks copied verbatim from a Claude Code plugin (PascalCase events, no `version` field) — Cursor's hooks.json is a different schema; see `cursor-hooks-and-agents`.
- Assuming Team Marketplace delivery on a non-Teams/Enterprise plan, or assuming non-GitHub repos work there.
- Docs that tell users to "run `/plugin install`" — Cursor installs are UI-driven (Marketplace panel, dashboard, or local directory).

## Sources

- Cursor, *Plugins* — manifest, component bundle, layout, marketplace.json, install scopes, local plugins ([cursor.com/docs/plugins](https://cursor.com/docs/plugins)). Verified 2026-06-09.
- Cursor, official plugins monorepo — ~13 MIT plugins, reference layouts ([github.com/cursor/plugins](https://github.com/cursor/plugins)). Verified 2026-06-09.
- Cursor changelog — 2.5 (plugins + marketplace, Feb 17, 2026), 2.6 (Team Marketplaces, Mar 3, 2026), 3.7 current ([cursor.com/changelog](https://cursor.com/changelog)). Verified 2026-06-09.
- Cursor, *Marketplace publishing* — manual review, open-source requirement ([cursor.com/marketplace/publish](https://cursor.com/marketplace/publish)). Verified 2026-06-09.

When upstream behavior changes, update the references — not this SKILL.md.
