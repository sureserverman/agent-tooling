---
name: cowork-plugin-development
description: Use when authoring a plugin for Claude Cowork. Triggers on "build a Cowork plugin", "Cowork install paths", "private marketplace limits", "Cowork ZIP upload", "which hook events fire in Cowork", "multilingual skill triggers", "connector-aware enrichment", "privacy posture for cloud Routines".
---

# cowork-plugin-development

Cowork is a chat-shaped surface in Claude Desktop, launched alongside Claude Code and using the same agentic architecture. It runs the same plugin format (`.claude-plugin/plugin.json`, `skills/`, `agents/`, `commands/`, `hooks/`), but several things differ enough to bite plugin authors who only target Code:

- Plugin install is **UI-driven** — four paths exist as of June 2026 (Anthropic catalog, direct ZIP upload, marketplace by URL, org private marketplaces), each with its own limits. There is no `/plugin marketplace add` slash flow inside Cowork chat.
- **Hooks and sub-agents run only in Cowork** — they're grayed out in chat sessions. And while hooks are supported, **Anthropic publishes no list of which hook events Cowork fires** — don't assume Claude Code's full 32-event set carries over.
- **Connectors** (MCP via Anthropic's cloud) replace local MCP. **Local stdio MCP servers are NOT supported** — a custom connector must be reachable from the public internet via Anthropic's IP ranges.
- The **chat register** dominates. Skills designed for terminal-resident users tend to feel wrong; skills designed for chat-resident users tend to feel right. Plugin skills also surface in Claude web chat and the Desktop Chat tab — your skill may fire outside Cowork entirely.

This skill teaches the patterns that make a Cowork plugin feel native, the distribution paths and their real limits, and the gotchas that aren't documented anywhere central. All platform facts verified against Anthropic's docs on 2026-06-09.

## Reference map

| When you need… | Read first |
|---|---|
| Cowork-vs-Code parity matrix, component support (hooks/agents/connectors), package limits, reserved names, org distribution states | `references/cowork-platform.md` |
| The four install paths, org private-marketplace limits (ZIP vs GitHub sync), GitHub Actions release workflow, README install-section shape | `references/cowork-distribution.md` |
| Multilingual triggers, connector-aware enrichment, privacy posture, refuse-without-prereq, save-and-resume, "## In Cowork" skill convention | `references/cowork-design-patterns.md` |
| Copy-paste release.yml that builds a single all-in-one zip on tag | `examples/release-workflow.yml` |
| Sample skill demonstrating multilingual triggers + connector-aware enrichment + In Cowork section | `examples/cowork-aware-skill.md` |

## Decision rules

### Should this plugin target Code, Cowork, or both?

| Signal | Pick |
|---|---|
| User runs commands in a terminal, edits files via shell, uses git constantly | **Code** |
| User talks in chat, attaches PDFs, asks for daily rhythms (briefings, digests, summaries) | **Cowork** |
| Plugin uses Connectors (Gmail / Calendar / Drive / Slack via Anthropic's cloud) | **Cowork-only** — Connectors are not available in Code |
| Plugin needs a **local stdio MCP server** | **Code-only** — Cowork does not support local stdio MCP |
| Plugin uses Scheduled Tasks or Routines | **Cowork-only** — these primitives don't exist in Code |
| Plugin relies on LSP servers, monitors, themes, `bin/`, or output styles | **Code-only** — none of these appear in Cowork's plugin docs; treat as unsupported there |
| Plugin runs primarily through `Bash` for non-trivial system work | **Code** — Cowork runs Bash in a sandboxed VM separate from the host OS |
| Multilingual user-facing prompts, knowledge-work register, no terminal idioms | **Cowork** |

If the plugin works in both, **target Cowork-first** in the README and golden paths, and let Code be the implicit fallback. The reverse (Code-first with Cowork as a footnote) ages badly because Cowork has primitives Code doesn't.

### Should this plugin ship hooks?

**Yes, but with eyes open.** As of June 2026 Cowork supports plugin hooks — they run **only in Cowork sessions** (grayed out in regular chat). Two caveats shape the design:

1. **No published event list.** Anthropic does not document which hook events Cowork fires. Claude Code's full event set (32 events as of 2026) is NOT guaranteed. Treat every hook as unverified until you've tested it in an actual Cowork session.
2. **Chat-surface fallback.** If your plugin's skills also fire in Claude web chat or the Desktop Chat tab, hooks won't be there. Any behavior a hook enforces needs an in-skill fallback (confirmation steps, closing-block discipline) for hook-less surfaces.

Design rule: hooks are an **enrichment layer**, never the load-bearing contract. Workflows must remain correct when no hook fires. Test each hook in Cowork before shipping; document in your README which events you verified.

### How will users install this plugin?

Four paths as of June 2026, in order of reach:

1. **Official Anthropic catalog** — Customize → Plugins → Browse. Curated; you don't control inclusion.
2. **Direct ZIP upload** — any user uploads a plugin ZIP on the Plugins page. Always works; the universal fallback.
3. **Marketplace by URL** — users add a marketplace via GitHub `owner/repo` shorthand, public GitLab, or Bitbucket URL. GitHub Enterprise works target-side only.
4. **Org private marketplace** — Team/Enterprise owners (requires Cowork + Skills enabled) publish via manual ZIP (≤50 MB, 100 plugins per marketplace, same-name overwrites) or GitHub sync (private repos on github.com only — Enterprise Server unsupported; auto-sync on merged PRs; 500 plugins; **npm and pip sources unsupported**).

Default recommendation for an independent author: ship a public repo that works as a URL marketplace **and** attach release ZIPs for the direct-upload path. See `references/cowork-distribution.md` for the full limits table and the release workflow.

### Will the package fit?

Hard limits enforced at upload/sync (June 2026):

- **200 MB uncompressed** and **5,000 files** per plugin.
- Plugin names: lowercase-hyphen, **≤64 chars**, and a **reserved-name list** is enforced (`claude-code-marketplace`, `anthropic-plugins`, `agent-skills`, among others).
- Marketplace archive ≤512 MB; users can add at most 25 marketplaces.

Run this plugin's deterministic validator before shipping: `bash scripts/validate.sh <package-dir>` checks name rules, reserved names, size/file-count (warns at 80%), npm/pip marketplace sources, and stdio MCP servers.

### Should the plugin's marketplace.json describe a multi-plugin bundle?

Yes, if you want the URL-marketplace or org-sync paths — it's load-bearing there, not just a Code-side convenience. Constraints that matter:

- **Relative-path sources are fully supported** in org GitHub sync — the safe default.
- External `github` / `url` / git-subdir sources work in org sync **only if the target repo is public**.
- **npm and pip sources are unsupported** in Cowork org marketplaces — don't ship them in a Cowork-bound marketplace.json.
- Sync runs on merged PRs with a 30-minute timeout; a failed sync can temporarily remove plugins from the org marketplace, so keep the manifest small and valid.

### Should skills auto-fire, or wait for `/<command>`?

For Cowork, **skill auto-trigger is the dominant pattern**. The user is in chat, they don't know your slash commands, they describe their need in natural language. Slash commands are a fallback for power users.

Design rule: every workflow that should be reachable from natural-language phrasing has a **skill with a multilingual `description`**. Slash commands are thin wrappers when an explicit invocation is useful.

Remember skills travel further than the rest of the plugin: per Anthropic's support docs they also surface in Claude web chat and the Desktop Chat tab, where hooks and sub-agents are grayed out. Write skills that degrade gracefully without their sibling components.

For description discipline (length, leak risk, multilingual triggers), see `cowork-design-patterns.md` and the `skill-development` / `skill-description-leak-audit` skills in the plugin-dev plugin.

### Where do connectors fit in?

Connectors are Cowork's MCP story — MCP via Anthropic's cloud, **opt-in per user**. Two hard constraints:

- **Local stdio MCP is not supported.** A `.mcp.json` with a `command` key does nothing useful in Cowork.
- **Custom connectors must be reachable from the public internet** via Anthropic's IP ranges. LAN-only services can't be connectors.

Never gate a skill on a connector being available — design skills to work without connectors and **enrich** when one is granted. The convention: every skill that benefits from a connector grows a `## In Cowork (connector-aware enrichment)` section in the body. See `cowork-design-patterns.md`.

### How does org distribution change the design?

Enterprise/Team owners assign each plugin one of four states: **Required > Installed by default > Available for install > Not available** (most-permissive wins when a user is in multiple Enterprise groups). Consequences for authors:

- **Required plugins are non-removable** by the user — a Required plugin that fires too eagerly is an org-wide irritation. Tune triggering conservatively if you expect Required deployment.
- **Locally edited plugin files trigger update warnings** — don't design workflows that ask users to hand-edit files inside the installed plugin; use settings/state files outside the plugin instead.

### Should this plugin ship Routine templates?

Maybe. Routines are cloud-hosted Cowork automations. They transit Anthropic's cloud, which changes the privacy posture.

Ship Routine templates **as documentation**, not as auto-installed automations. Put them under `routines/` in the plugin. Each template has a privacy header naming what data crosses the cloud boundary, is named `<workflow>-routine.md`, names the connectors it expects, and names the trigger. Some workflows should **not** be routinable for privacy reasons — make this explicit in routines/README.md. Full pattern in `cowork-design-patterns.md`.

### Is `Bash` use safe in Cowork?

Bash runs in Cowork's sandboxed VM, separate from the host OS. That's good for safety but means:

- **Filesystem access is granular per-folder** — the user grants specific folders. Don't assume `~/.claude/` is readable; check.
- **Network access is sandboxed** — most outbound HTTP works; some host-resolved connections may not.
- **Long-running processes are constrained** — the VM is per-task, not persistent. Don't design skills that need a daemon.
- **Host-OS-specific tooling is unavailable** — no `launchctl`, no `crontab` (use Cowork's Scheduled Tasks instead), no `osascript`.

When in doubt, prefer Cowork's first-class primitives (connectors, scheduled tasks, routines, file uploads) over Bash automation.

## Anti-patterns this skill catches

- A `.mcp.json` with **local stdio servers** (`command` key) in a Cowork-bound plugin — Cowork only supports MCP via cloud connectors. The deterministic lane flags this (`cowork-mcp-stdio`).
- A marketplace.json with **npm or pip sources** destined for an org private marketplace — unsupported; sync will not deliver them.
- A plugin named off the reserved list (`anthropic-plugins`, `agent-skills`, …) or >64 chars / not lowercase-hyphen — rejected at upload.
- A hook that's **load-bearing** — Cowork's fired-event list is unpublished, and skills also surface in chat where hooks never run. Hooks enrich; skills must stand alone.
- Documentation that says **"install via `/plugin marketplace add`"** as the only path — that's Code's flow. Document the Cowork paths: catalog, ZIP upload on the Plugins page, marketplace by URL.
- A `setup-X.md` command that prints a `crontab -e` snippet — Cowork has no crontab. Use the Scheduled Tasks UI flow.
- A skill that **assumes connector data is always available** — connectors are opt-in. Skill must work without them.
- A SKILL.md description that's >800 chars and lists 8+ language triggers verbatim — risks UI truncation. Move the long list to a "Triggers" section in the body.
- A Routine template without a privacy header — users can't tell which workflows are safe for cloud transit.
- A workflow that tells users to **edit files inside the installed plugin** — locally edited plugin files trigger update warnings in org deployments.

## Sources

- Anthropic, *Plugins in Claude Cowork* — install paths, component support (skills / connectors / agents / hooks), package limits, connector reachability requirements ([claude.com/docs/cowork/guide/plugins](https://claude.com/docs/cowork/guide/plugins)). Verified 2026-06-09.
- Anthropic, *Use plugins in Claude Cowork* — catalog browse, ZIP upload, marketplace by URL, hooks/sub-agents Cowork-only (grayed out in chat), skills surfacing in Claude web chat + Desktop Chat tab ([support.claude.com article 13837440](https://support.claude.com/en/articles/13837440)). Verified 2026-06-09.
- Anthropic, *Manage Claude Cowork plugins for your organization* — private marketplace limits (manual ZIP ≤50 MB / 100 plugins; GitHub sync github.com-only / 500 plugins / npm+pip unsupported / 30-min timeout), distribution states, reserved names ([support.claude.com article 13837433](https://support.claude.com/en/articles/13837433)). Verified 2026-06-09.

These are the primary sources every claim in the references folder rests on. One deliberate unknown: **which hook events Cowork fires is not published anywhere** — the references mark it UNKNOWN rather than guessing. When upstream behavior changes, update the references — not this SKILL.md.
