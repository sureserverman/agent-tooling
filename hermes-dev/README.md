# hermes-dev

Authoring kit for **Hermes Agent** — Nous Research's open-source autonomous agent harness ([github.com/NousResearch/hermes-agent](https://github.com/NousResearch/hermes-agent)), **not** the Hermes model family. Part of the [`coder-plugins`](..) marketplace.

> **Volatility warning.** Hermes ships multiple minor releases per month — v0.14→v0.16 landed within May–June 2026. Everything below is current as of **v0.16.0 "The Surface Release" (June 5, 2026)**, verified 2026-06-09 against hermes-agent.nousresearch.com/docs. **Re-verify plugin-API specifics against the current docs before shipping anything.**

## Why a separate hermes-dev?

Hermes reads the same agentskills.io SKILL.md as Claude Code, Cursor, and Codex — and then diverges exactly where extensions break. As of June 2026 (Hermes Agent v0.16):

- **Skills need a `version` frontmatter field** (no other host requires it) and live under `~/.hermes/skills/<category>/<skill-name>/` — note the **category** level; a skill dropped one level up is never indexed. Hermes-only knobs go under `metadata.hermes.*`; shared trees plug in via `skills.external_dirs`.
- **Hermes edits its own skills**: the autonomous `skill_manage` tool creates and patches skills after complex tasks — authored skills must expect machine edits, which is why `version` matters.
- **Distribution is its own ecosystem**: `hermes skills install` (official catalog, skills.sh, direct SKILL.md URLs, ClawHub/LobeHub), Homebrew-style GitHub taps (defaults include openai, anthropics, huggingface, NVIDIA), `/.well-known/skills/index.json` endpoints, skill bundles, and an install-time security scan (injection/exfiltration/destructive commands).
- **Plugins are Python packages**, nothing like Claude Code's: `plugin.yaml` + `__init__.py` with `register(ctx)` (`register_tool`/`register_hook`/`register_command`/`register_skill`, `override=True` for built-ins), pip-distributable via `hermes_agent.plugins` entry points. Handler contract: args dict in, **JSON string out, never raise**. Memory providers and context-compression engines are plugin types too.
- **Config is one `~/.hermes/config.yaml` for every surface** — CLI/TUI, a 23-platform messaging gateway, web dashboard, desktop app — with persona in SOUL.md, durable facts in MEMORY.md/USER.md, and project context auto-loaded from `.hermes.md`/`HERMES.md`/`AGENTS.md`/**`CLAUDE.md`**/`.cursorrules`. MCP wiring covers stdio + HTTP (OAuth 2.1, mTLS), and `hermes mcp serve` exposes Hermes itself as an MCP server.

[`plugin-dev`](../plugin-dev) owns plugin *structure* for Claude Code; **hermes-dev owns the Hermes platform**: skill format and distribution, the Python plugin API, and configuration/MCP. All platform facts are sourced and dated (verified 2026-06-09).

## Balanced by design — the determinism boundary

Like every plugin in this marketplace, hermes-dev keeps mechanical checks out of the LLM's hands:

- **Deterministic lane → `scripts/`.** `validate-hermes-artifact.sh` checks a Hermes-bound artifact: plugin.yaml parse/required-fields/list-types, `register(ctx)` presence in `__init__.py`, SKILL.md frontmatter including the Hermes-required `version` (`hermes-skill-no-version`), `metadata.hermes` shape, config.yaml `mcp_servers` entries (command-or-url), and Python syntax — on the shared JSON finding contract from plugin-dev's determinism kit.
- **Semantic lane → the skills.** Format choices (skill vs plugin, bundle vs single skill, hook event selection, stdio vs HTTP MCP, what belongs in SOUL.md vs config.yaml) stay with the three skills, which consume the script output rather than re-deriving the rules.

```bash
# gate an artifact before shipping it to Hermes users
bash scripts/validate.sh path/to/artifact --json | jq .
# self-test against the bundled fixtures
bash scripts/validate.sh tests/fixtures/good   # passes
bash scripts/validate.sh tests/fixtures/bad    # fails: manifest fields, missing register(ctx),
                                               # Python syntax, versionless skill, dead MCP entry
```

See [`scripts/README.md`](scripts/README.md) for the rule-id table and the contract.

## Installation

```bash
/plugin marketplace add sureserverman/coder-plugins
/plugin install hermes-dev@coder-plugins
```

## Components

### Skills (3)

| Skill | Triggers when you ask |
|---|---|
| `hermes-skills` | "Hermes skill", "write a skill for Hermes", "hermes skills install", "skill bundle", "Hermes skill tap" |
| `hermes-plugin-development` | "Hermes plugin", "plugin.yaml", "register(ctx)", "Hermes register_tool", "Hermes hook pre_tool_call" |
| `hermes-config` | "Hermes config.yaml", "SOUL.md", "Hermes MCP", "hermes mcp serve", "Hermes persona" |

Depth lives in each skill's `references/` (skill format + distribution; plugin format + register API; config + MCP). Every skill repeats the volatility warning — re-verify before shipping.

### Scripts

| Script | Does |
|---|---|
| `scripts/validate.sh <artifact-dir> [--json]` | Orchestrator — runs every domain validator, merges findings, prints one verdict. |
| `scripts/validate-hermes-artifact.sh` | The Hermes-bound artifact checks (plugin.yaml, register(ctx), skill frontmatter + version, metadata.hermes, config.yaml MCP entries, Python syntax). |

## Anti-patterns this plugin will catch

- A skill ported from Claude Code without a `version` field — only Hermes requires it; update/`skill_manage` flows depend on it.
- A skill dropped at `~/.hermes/skills/<name>/` — missing the category level; never indexed.
- A tool handler that raises or returns a dict — the contract is a JSON **string**, never an exception.
- `provides_tools: a, b` in plugin.yaml — must be a YAML list.
- An `mcp_servers` entry with neither `command` nor `url` — dead config.
- CLAUDE.md duplicated into HERMES.md — Hermes auto-loads CLAUDE.md from the project root.
- Treating the plugin API as stable across minors — it's younger than the skills surface; pin and re-verify.

## License

MIT
