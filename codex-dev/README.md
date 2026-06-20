# codex-dev

Authoring kit for **OpenAI Codex** (CLI + IDE extension) extensions. Part of the [`coder-plugins`](..) marketplace.

## Why a separate codex-dev?

Codex superficially shares formats with Claude Code (agentskills.io SKILL.md, hooks.json shape), but the platform rules differ exactly where extensions break. As of June 2026 (Codex CLI v0.139):

- **Plugins read `.codex-plugin/plugin.json`**, not `.claude-plugin/` — with `./`-prefixed component pointers, Codex-specific marketplace machinery under `.agents/plugins/`, and a public Plugin Directory that is still "coming soon".
- **Skills discover from `.agents/skills/` trees** (`~/.claude/skills` is never read), compete inside a ~2%-of-context catalog cap, and can carry a Codex-only `agents/openai.yaml` sidecar. Custom prompts are deprecated in favor of skills.
- **Subagents are one TOML file per agent** with required `developer_instructions` — nothing like Claude Code's markdown agents — and Codex spawns them only on explicit request.
- **config.toml broke in v0.134.0**: `[profiles.*]` tables and top-level `profile=` were removed — old configs **fail at startup**; overlays (`$CODEX_HOME/<name>.config.toml` + `codex --profile`) replace them. Project configs can't override provider/auth, notifications, profile selection, or telemetry.
- **Hooks don't run until trusted**: the 10-event engine (v0.114.0) requires unmanaged command hooks to be approved via `/hooks` — the top cause of "my hook doesn't fire".

[`plugin-dev`](../plugin-dev) owns plugin *structure* for Claude Code; **codex-dev owns the Codex platform**: formats, discovery, config, hooks, MCP wiring, and AGENTS.md briefing. All platform facts are sourced and dated (verified 2026-06-09).

## Balanced by design — the determinism boundary

Like every plugin in this marketplace, codex-dev keeps mechanical checks out of the LLM's hands:

- **Deterministic lane → `scripts/`.** `validate-codex-artifact.sh` checks a Codex-bound artifact: `.codex-plugin/plugin.json` presence + `./`-pointer resolution, SKILL.md frontmatter, agent-TOML required fields, legacy `[profiles.*]`/`profile=` residue (`codex-legacy-profile`), and hooks.json event names — on the shared JSON finding contract from plugin-dev's determinism kit.
- **Semantic lane → the skills.** Format choices (plugin vs bare skills dir, skill vs subagent, hook vs notify, approval/sandbox pairing, AGENTS.md layering) stay with the three skills, which consume the script output rather than re-deriving the rules.

```bash
# gate an artifact before shipping it to Codex users
bash scripts/validate.sh path/to/artifact --json | jq .
# self-test against the bundled fixtures
bash scripts/validate.sh tests/fixtures/good   # passes
bash scripts/validate.sh tests/fixtures/bad    # fails: pointers, frontmatter, agent TOML, legacy profiles, unknown event
```

See [`scripts/README.md`](scripts/README.md) for the rule-id table and the contract.

## Installation

```bash
/plugin marketplace add sureserverman/coder-plugins
/plugin install codex-dev@coder-plugins
```

## Components

### Skills (3)

| Skill | Triggers when you ask |
|---|---|
| `codex-plugin-development` | "build a Codex plugin", ".codex-plugin manifest", "Codex marketplace", "codex marketplace add", "plugin.json for Codex" |
| `codex-skills-and-agents` | "Codex skill", "$skill in Codex", "agents/openai.yaml", "Codex subagent", "custom prompts deprecated", "Codex skill discovery" |
| `codex-config-and-hooks` | "config.toml for Codex", "Codex profile", "Codex hooks", "Codex MCP server", "AGENTS.md discovery", "Codex sandbox config" |

Depth lives in each skill's `references/` (plugin format + marketplaces; skills + subagents; config.toml + hooks + AGENTS.md).

### Scripts

| Script | Does |
|---|---|
| `scripts/validate.sh <artifact-dir> [--json]` | Orchestrator — runs every domain validator, merges findings, prints one verdict. |
| `scripts/validate-codex-artifact.sh` | The Codex-bound artifact checks (manifest, pointers, frontmatter, agent TOML, legacy profiles, hook events). |

## Anti-patterns this plugin will catch

- A Claude Code plugin "ported" by renaming directories — Codex reads `.codex-plugin/plugin.json` with its own fields and `./`-prefixed pointers.
- `[profiles.work]` or `profile = "work"` left in config.toml — startup failure since v0.134.0.
- Skills installed to `~/.claude/skills` and expected to load — Codex reads `.agents/skills` trees.
- Agent TOML missing `developer_instructions`, or several agents merged into one file.
- Hooks shipped without telling users to trust them via `/hooks` — they silently never run.
- New automation written as a custom prompt — deprecated; write a skill.

## License

MIT
