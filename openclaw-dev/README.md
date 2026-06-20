# openclaw-dev

Authoring kit for **OpenClaw** extensions — skills, plugins, and automation for the open-source personal AI assistant by Peter Steinberger (renamed Clawdbot → Moltbot → OpenClaw in January 2026; CalVer releases, current 2026.6.5). Part of the [`coder-plugins`](..) marketplace.

## Why a separate openclaw-dev?

OpenClaw reads the same AgentSkills `SKILL.md` base format as Claude Code and Codex, but the platform rules differ exactly where extensions break. As of June 2026 (OpenClaw 2026.6.5):

- **Skill frontmatter `metadata` must be single-line JSON** (`metadata: {"openclaw": {...}}`) — a nested YAML block is valid YAML and silently wrong. Skills load through a **six-level precedence** where same-name skills **silently shadow** (no merging), gate on `requires.bins/anyBins/env/config` + `os` at load, and are **snapshotted at session start** — mid-session edits need the watcher or a new session.
- **Plugins require BOTH manifests**: a `package.json` `openclaw` field (`extensions`, `compat.pluginApi`) *and* an `openclaw.plugin.json` (`id`, `contracts`, `toolMetadata`, `activation`). The root SDK barrel `openclaw/plugin-sdk` is **deprecated** in favor of focused subpaths, tool-name conflicts with core are silently skipped, and **every install/update needs a Gateway restart**. Plugins run **in-process with the Gateway** — trusted code, allowlist-and-pin doctrine.
- **Automation is four surfaces**, not one: `HOOK.md` + `handler.ts` internal hooks (typed events; workspace hooks disabled by default), the Gateway cron scheduler (SQLite-backed; `--system-event` / `--message` / `--command` payloads; bare timestamps are UTC), `/hooks` webhooks (Bearer/`x-openclaw-token` only — query-string tokens get a 400), and the `HEARTBEAT.md` heartbeat (default 30 min). Rule: **cron for precise timing, heartbeat for context-rich periodic assessment**.
- **`openclaw.json` is JSON5 with a STRICT schema** — one unknown key prevents Gateway start (`openclaw doctor` recovers; last-known-good is kept).
- Distribution runs through **ClawHub** (clawhub.ai, 13k+ skills) — commit-pinned installs and install-policy validation since 2026.6.5; publishing needs a GitHub account ≥1 week old.

[`plugin-dev`](../plugin-dev) owns Claude Code plugin *structure*; **openclaw-dev owns the OpenClaw platform**: formats, precedence, gating, manifests, automation surfaces, and gateway config. All platform facts are sourced and dated (verified 2026-06-09 against docs.openclaw.ai).

## Balanced by design — the determinism boundary

Like every plugin in this marketplace, openclaw-dev keeps mechanical checks out of the LLM's hands:

- **Deterministic lane → `scripts/`.** `validate-openclaw-artifact.sh` checks an OpenClaw-bound artifact: dual-manifest presence (`openclaw.plugin.json` id + `package.json` openclaw field), `openclaw.extensions` path resolution, deprecated root-barrel SDK imports, SKILL.md frontmatter and the signature **single-line metadata JSON** rule, hook `handler.ts` presence and non-empty `events`, and `openclaw.json` JSON5 parse — on the shared JSON finding contract from plugin-dev's determinism kit.
- **Semantic lane → the skills.** Platform judgment (where a skill should live, gate honesty, plugin vs channel plugin, cron vs heartbeat, security posture) stays with the three skills, which consume the script output rather than re-deriving the rules.

```bash
# gate an artifact before shipping it to OpenClaw users
bash scripts/validate.sh path/to/artifact --json | jq .
# self-test against the bundled fixtures
bash scripts/validate.sh tests/fixtures/good   # passes
bash scripts/validate.sh tests/fixtures/bad    # fails: id-less manifest, missing openclaw field,
                                               # multi-line metadata YAML, handler-less hook, root barrel
```

See [`scripts/README.md`](scripts/README.md) for the rule-id table and the contract.

## Installation

```bash
/plugin marketplace add sureserverman/coder-plugins
/plugin install openclaw-dev@coder-plugins
```

## Components

### Skills (3)

| Skill | Triggers when you ask |
|---|---|
| `openclaw-skills` | "OpenClaw skill", "openclaw metadata frontmatter", "skill not loading in OpenClaw", "ClawHub skill", "OpenClaw workspace skills" |
| `openclaw-plugin-development` | "OpenClaw plugin", "openclaw.plugin.json", "definePluginEntry", "channel plugin", "OpenClaw plugin SDK" |
| `openclaw-automation` | "OpenClaw hook", "HOOK.md", "openclaw cron", "OpenClaw webhook", "heartbeat vs cron", "OpenClaw gateway config" |

Depth lives in each skill's `references/` (skill format + ClawHub distribution; plugin format + channel plugins; hooks + cron, webhooks + heartbeat, gateway config + workspace).

### Scripts

| Script | Does |
|---|---|
| `scripts/validate.sh <artifact-dir> [--json]` | Orchestrator — runs every domain validator, merges findings, prints one verdict. |
| `scripts/validate-openclaw-artifact.sh` | The OpenClaw-bound artifact checks (dual manifests, metadata JSON, hooks, config parse). |

## Anti-patterns this plugin will catch

- `metadata:` written as a nested YAML block in SKILL.md or HOOK.md — must be single-line JSON (`openclaw-skill-metadata-json`).
- A plugin shipping only one of its two required manifests, or `openclaw.extensions` pointing at nothing.
- `import { definePluginEntry } from "openclaw/plugin-sdk"` — deprecated root barrel; focused subpaths only.
- A `HOOK.md` directory without `handler.ts`, or with an empty `events` list — the hook never fires.
- A speculative key hand-added to `openclaw.json` — strict schema; the Gateway won't start.
- "Installed the plugin but nothing happened" — no Gateway restart.
- Same-name skill at two precedence levels treated as a merge — the higher one silently wins wholesale.
- Webhook tokens in the query string, or the gateway auth token reused as the webhook secret.

## License

MIT
