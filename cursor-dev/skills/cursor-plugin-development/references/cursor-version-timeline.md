# Cursor feature timeline, 2.4 → 3.7 (verified 2026-06-09)

Why this exists: "does the user's Cursor have X?" decides what a plugin can
depend on. Map features to versions before assuming them.

| Version | Date | Extension-relevant changes |
|---|---|---|
| 2.4 | Jan 2026 | **Subagents** and **skills** land — `.cursor/agents/`, agentskills.io-standard skills with the Cursor discovery paths |
| 2.5 | Feb 17, 2026 | **Plugins + public marketplace** — `.cursor-plugin/plugin.json`, in-editor Marketplace panel, cursor.com/marketplace, project/user install scopes, local plugins |
| 2.6 | Mar 3, 2026 | **Team Marketplaces** (private GitHub-repo plugins, required/optional per SCIM group, ≤10-min auto-refresh) + **MCP Apps** |
| 3.0 | Apr 2, 2026 | **Agent-first UI** — major surface reshuffle; agent pane is the primary interface |
| ~3.x | Apr 2026 | **Cursor Agent SDK** (TypeScript/Python) — programmatic agent surface, separate from plugins |
| 3.6 | May 2026 | **permissions.json** (relaxes MCP/tool approval prompts) + **Auto-review** |
| 3.7 | Jun 4–5, 2026 | Current release. Agent SDK gains **custom tools and stores** |

## Compatibility rules of thumb

- A plugin that ships **only rules** works on anything ≥2.5 (plugin packaging)
  — and the rules themselves work standalone in any modern Cursor via
  `.cursor/rules/`.
- Skills and subagents inside a plugin: ≥2.5 (the components themselves
  predate plugins — 2.4 — but plugin delivery needs 2.5).
- Team Marketplace delivery: ≥2.6 **and** a Teams/Enterprise plan.
- A plugin README that references `permissions.json` to pre-approve its MCP
  servers: ≥3.6.
- MCP Apps: ≥2.6.

## The Agent SDK is not a plugin

The Cursor Agent SDK (Apr 2026; TS + Python; custom tools/stores in 3.7) lets
external code drive Cursor's agent — CI bots, server-side automation, custom
UIs. It is a **separate programmatic surface** with its own docs and release
cadence. cursor-dev covers plugins/rules/skills/hooks/agents/MCP — the
*editor-resident* surfaces. For SDK work, send the user to cursor.com/docs and
do not improvise SDK APIs from plugin knowledge.

Source: [cursor.com/changelog](https://cursor.com/changelog),
[cursor.com/docs/plugins](https://cursor.com/docs/plugins). Verified
2026-06-09.
