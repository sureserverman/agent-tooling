# Cowork platform reference

What Cowork is, how it differs from Claude Code, what plugin components it actually supports, the package limits it enforces, and how org distribution works. All facts verified against Anthropic's docs on 2026-06-09 (sources at the end).

## What Cowork is

Claude Cowork is a chat-shaped knowledge-work surface in the Claude Desktop app, launched alongside Claude Code in early 2026. It uses **the same agentic architecture** that powers Claude Code, but exposes it through a chat UX rather than a terminal. Cowork went generally available on macOS and Windows on 2026-04-09 with analytics, OpenTelemetry, and role-based access controls for enterprise teams.

Cowork's mental model:

- The user types a request in chat.
- Claude breaks it into multi-step work.
- Sub-agents handle parallel sub-tasks.
- Tools (filesystem, web, connectors) are invoked transparently.
- Long-running work fires on schedule (Scheduled Tasks) or in the cloud (Routines).

Cowork is built for knowledge workers — sales, finance, legal, marketing, HR, operations, design, data analysis — not for software engineering. Plugins are available on **all paid plans**; private (org) marketplaces are Team/Enterprise only.

## Component support (June 2026)

| Component | Supported in Cowork? | Notes |
|---|---|---|
| Skills (`skills/<name>/SKILL.md`) | ✅ | The primary surface. Plugin skills also surface in **Claude web chat and the Desktop Chat tab** (per support article 13837440) — design them to stand alone. |
| Connectors (MCP) | ✅ via Anthropic's cloud | **Local stdio MCP is NOT supported.** Custom connectors must be reachable from the public internet via Anthropic's IP ranges. |
| Sub-agents (`agents/<name>.md`) | ✅ Cowork-only | Grayed out in chat sessions. |
| Hooks (`hooks/hooks.json`) | ✅ Cowork-only | Grayed out in chat sessions. **Which events fire is UNKNOWN** — see below. |
| Slash commands (`commands/<name>.md`) | ✅ | Surfaced via the `/` menu in Cowork. |
| LSP servers (`.lsp.json`) | ❌ treat as unsupported | Not mentioned in Cowork's plugin docs. |
| Monitors (`monitors/`) | ❌ treat as unsupported | Not mentioned in Cowork's plugin docs. |
| Themes / output styles | ❌ treat as unsupported | Not mentioned in Cowork's plugin docs. |
| `bin/` executables | ❌ treat as unsupported | Not mentioned in Cowork's plugin docs. |

"Not mentioned" is the operative standard: Anthropic's Cowork plugin docs enumerate skills, connectors, agents, and hooks. Anything outside that list has no documented Cowork behavior — ship it for Code, but don't make a Cowork workflow depend on it.

### Hook events: documented unknown

Anthropic publishes **no list of which hook events Cowork fires**. Claude Code fires 32 events as of 2026; Cowork may fire a subset, and the subset is not documented. Practical rules:

1. Test every hook in an actual Cowork session before shipping.
2. Never make a hook load-bearing — workflows must be correct with zero hooks fired (this also covers chat surfaces, where hooks are grayed out entirely).
3. Document in your README which events you verified, and when.

## Parity with Claude Code

| Capability | Code | Cowork | Notes |
|---|---|---|---|
| Plugin format (`.claude-plugin/plugin.json`) | ✅ | ✅ | Same schema |
| Skills | ✅ | ✅ | Auto-fire on description match in both; Cowork skills also reach Claude web chat + Desktop Chat tab |
| Sub-agents | ✅ | ✅ (Cowork sessions only) | Grayed out in chat |
| Slash commands | ✅ | ✅ | Surfaced via `/` menu in Cowork |
| Hooks | ✅ (32 documented events) | ✅ (Cowork sessions only; fired-event list unpublished) | Test in Cowork; don't assume parity |
| Local stdio MCP (`.mcp.json` with `command`) | ✅ | ❌ | Cowork MCP = cloud connectors only |
| Remote MCP / connectors | ✅ (remote MCP) | ✅ (connectors via Anthropic's cloud) | Custom connectors must be publicly reachable via Anthropic IP ranges |
| Filesystem read/write | ✅ (project-rooted) | ✅ (per-folder permission) | Cowork requires explicit folder grants |
| `Bash` tool | ✅ (host shell) | ✅ (sandboxed VM, separate from host OS) | Cowork's VM is per-task, not persistent |
| `WebFetch` / `WebSearch` | ✅ | ✅ | Same surfaces |
| Install via `/plugin marketplace add` | ✅ | ❌ | Cowork install is UI-driven (see the four paths below) |
| Marketplace by URL | ✅ | ✅ | GitHub `owner/repo` shorthand, public GitLab, Bitbucket; GitHub Enterprise target-side only |
| Org private marketplaces | ✅ | ✅ (Team/Enterprise owners) | Requires Cowork + Skills enabled for the org |
| Connectors (Gmail / Calendar / Drive / Slack) | ❌ | ✅ | Cowork-only; cloud-routed via Anthropic |
| Scheduled Tasks (cron-style, desktop) | ❌ | ✅ | Cowork-only; runs while desktop app open |
| Routines (cloud; schedule / webhook / GitHub event) | ❌ | ✅ | Cowork-only; runs in Anthropic cloud, laptop closed OK |
| File uploads in chat (PDF, image) | partial (via paths) | ✅ (drag-and-drop) | |
| LSP / monitors / themes / `bin/` / output styles | ✅ | ❌ (undocumented → treat as unsupported) | |

When porting a plugin from Code to Cowork, the things most likely to bite are: stdio MCP servers, untested hook events, install-path documentation, `Bash`-heavy workflows that depended on host-OS tools, and skills that assumed connector-style data was always available.

## Install paths (summary)

Full detail in `cowork-distribution.md`. The four paths as of June 2026:

1. **Official Anthropic catalog** — Customize → Plugins → Browse.
2. **Direct ZIP upload** — on the Plugins page; any paid-plan user.
3. **Marketplace by URL** — GitHub `owner/repo` shorthand, GitHub Enterprise (target-side only), public GitLab, Bitbucket.
4. **Org private marketplaces** — Team/Enterprise owners; requires Cowork + Skills enabled.

## Package limits (enforced)

| Limit | Value |
|---|---|
| Uncompressed plugin size | **200 MB** |
| Files per plugin | **5,000** |
| Marketplace archive | **512 MB** |
| Marketplaces a user can add | **25** |
| Org manual-ZIP upload | **50 MB**, 100 plugins per marketplace, same-name overwrites |
| Org GitHub-synced marketplace | **500 plugins** |
| Plugin name | lowercase-hyphen, **≤64 chars** |
| Reserved names | enforced list — `claude-code-marketplace`, `anthropic-plugins`, `agent-skills`, among others |

This plugin's deterministic lane (`scripts/validate.sh <package-dir>`) checks the per-package limits mechanically — name shape, reserved names, size and file count (warning at 80% of the cap), npm/pip marketplace sources, stdio MCP servers.

## Org distribution states

Team/Enterprise owners assign each plugin one of four states, ranked most- to least-permissive:

**Required** > **Installed by default** > **Available for install** > **Not available**

- When a user belongs to multiple Enterprise groups, the **most-permissive state wins**.
- **Required plugins are non-removable** by the user.
- **Locally edited plugin files trigger update warnings** — a reason to keep user state outside the plugin directory.

Author consequences: a plugin deployed as Required must have conservative triggering (the user can't uninstall it), and must never instruct users to edit its own installed files.

## Cowork-only primitives

### Connectors

Cowork's MCP layer — integrations with cloud services routed **via Anthropic's cloud**, opt-in per user. The user grants a connector once in Customize → Connectors; thereafter, skills and agents can read from / write to that service.

Common connectors as of 2026: Google Calendar, Gmail, Google Drive, DocuSign, Slack, GitHub, Linear/Jira, Microsoft 365.

Hard constraints:

- **Local stdio MCP servers do not run in Cowork.** A plugin `.mcp.json` whose servers use a `command` key is Cowork-incompatible.
- **Custom connectors must be reachable from the public internet via Anthropic's IP ranges.** A connector cannot reach a LAN-only service.
- Data flowing through a connector transits Anthropic's infrastructure during the call.

Plugin-author rule: **never gate a skill on a connector**. Always design the skill to work without connectors and *enrich* when one is granted. See `cowork-design-patterns.md` for the convention.

### Scheduled Tasks

Cron-style recurring tasks that fire while the user's Cowork desktop app is open (or whenever the next launch happens, if the scheduled time elapsed while closed). Created via:

- The `/schedule` slash command in any Cowork chat, OR
- The Scheduled sidebar item → + New task.

A Scheduled Task is **a saved prompt + a cadence** (hourly / daily / weekly / weekdays / custom cron). When it fires, Cowork opens a fresh chat session, runs the prompt, and stops. Tasks have access to the same connectors, plugins, and skills as a regular Cowork session.

Plugins that need a daily rhythm (briefings, digests, scans) should ship a **`setup-<rhythm>.md` slash command** that asks the user about cadence and walks them through pasting the right prompt into `/schedule`. The plugin does **not** call `/schedule` directly — that's a UI authorisation surface the user owns.

### Routines

Cloud-hosted Cowork automations introduced 2026-04-14. Routines run in Anthropic's cloud (laptop closed, network disconnected, OS asleep), and trigger on:

- **Schedule** (cron-style, like Scheduled Tasks but cloud-hosted).
- **Webhook** (Cowork generates a unique URL; external system POSTs to it).
- **GitHub event** (PR opened, issue labeled, push to a branch).
- **Linear event** (ticket status change), other connector-driven events.

A Routine bundles: a prompt, optionally a code repo (for Code-style work), and a set of granted connectors.

Privacy posture: Routines transit Anthropic's cloud. Plugin authors must surface this when a workflow is sensitive. The pattern in `cowork-design-patterns.md` calls for a privacy header on every Routine template.

Some workflows should **not** be Routine-able by design — anything involving reflection content, profile edits with material identity claims, or contracts under NDA. Make non-Routinable explicit in the plugin's `routines/README.md`.

## Historical notes (resolved / superseded)

Early 2026 guidance (including earlier versions of this reference) treated plugin-scope hooks as broken in Cowork (anthropics/claude-code#27398) and recommended ZIP upload as the only reliable path due to marketplace skill-loading failures (anthropics/claude-code#39400). As of June 2026, Anthropic's docs list hooks as supported components (Cowork-only) and document four install paths including URL marketplaces and org sync. The durable residue of that era is the design posture this skill still teaches: hooks as enrichment (now justified by the unpublished event list), and ZIP upload as the universal fallback path.

## Sources

- *Plugins in Claude Cowork* — [claude.com/docs/cowork/guide/plugins](https://claude.com/docs/cowork/guide/plugins). Verified 2026-06-09.
- *Use plugins in Claude Cowork* — [support.claude.com article 13837440](https://support.claude.com/en/articles/13837440). Verified 2026-06-09.
- *Manage Claude Cowork plugins for your organization* — [support.claude.com article 13837433](https://support.claude.com/en/articles/13837433). Verified 2026-06-09.
- *Get started with Claude Cowork* — [support.claude.com](https://support.claude.com/en/articles/13345190-get-started-with-claude-cowork).
- *Automate work with routines* — [code.claude.com](https://code.claude.com/docs/en/web-scheduled-tasks).
- *Cowork product page* — [claude.com/product/cowork](https://claude.com/product/cowork).
