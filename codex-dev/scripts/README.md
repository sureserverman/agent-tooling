# codex-dev — deterministic lane

This `scripts/` directory is codex-dev's **deterministic lane**, vendored from
the plugin-dev determinism kit. It encodes one rule:

> **Mechanical, decidable checks belong in scripts. Semantic judgment belongs to
> the LLM.** Scripts flag; the model decides and writes.

## Layout

```
scripts/
├── lib/findings.sh             # shared finding accumulator + JSON contract (from plugin-dev; do not fork)
├── validate.sh                 # orchestrator — discovers and runs every validate-*.sh, merges, prints a verdict
└── validate-codex-artifact.sh  # codex-dev's domain validator: Codex-bound artifact checks
```

## Usage

The target is a **Codex-bound artifact directory** — a Codex plugin package,
skills tree, agents directory, or config drop. That is usually *another*
artifact, not codex-dev itself:

```bash
bash scripts/validate.sh <artifact-dir> [--json]
```

`--json` emits the contract (consumed by skills/agents); without it, a human
report. Exit code: `1` if any error, else `0` (`2` usage, `3` jq missing).
Requires `jq`; the TOML/YAML checks additionally need `python3` (stdlib
`tomllib` + `pyyaml`) and degrade to a warning when it is absent.

Self-test fixtures live in `tests/fixtures/`:

```bash
bash scripts/validate.sh tests/fixtures/good   # exit 0, verdict pass
bash scripts/validate.sh tests/fixtures/bad    # exit 1 — bad pointers, broken frontmatter,
                                               # agent TOML, legacy profiles, unknown hook event
```

## What validate-codex-artifact.sh checks (June 2026 facts, Codex CLI v0.139.0)

| Rule id | Severity | Check |
|---|---|---|
| `codex-manifest-missing` / `codex-manifest-unparseable` | error | `.codex-plugin/plugin.json` exists and parses (NOT `.claude-plugin/`) |
| `codex-manifest-name-missing` | error | manifest has a `name` |
| `codex-manifest-pointer` | error | every component pointer (`skills`, `mcpServers`, `apps`, `hooks`) starts with `./` and resolves to an existing path |
| `codex-skill-frontmatter` | error | each `skills/*/SKILL.md` has closed YAML frontmatter with non-empty `name` + `description` |
| `codex-agent-toml` | error | each `agents/*.toml` parses (tomllib) and carries `name` + `description` + `developer_instructions` |
| `codex-config-unparseable` | error | every `config.toml` in the artifact parses (tomllib) |
| `codex-legacy-profile` | error | no `[profiles.*]` table and no top-level `profile=` key in any config.toml — **removed in v0.134.0; Codex fails at startup** |
| `codex-hooks-unparseable` | error | every `hooks.json` parses |
| `codex-hook-unknown-event` | warn | hook event names are within the 10 lifecycle events (engine v0.114.0): SessionStart, SubagentStart, UserPromptSubmit, PreToolUse, PermissionRequest, PostToolUse, PreCompact, PostCompact, SubagentStop, Stop |
| `codex-python-missing` | warn | python3/pyyaml absent — TOML/YAML checks skipped |

Scan exclusions: `.git/`, `node_modules/`, and `tests/fixtures/` (test data) are
pruned from the config.toml and hooks.json scans so self-scans stay clean.

Facts verified 2026-06-09 against developers.openai.com/codex (config-reference,
config-advanced, hooks, mcp, plugins), Codex CLI v0.139.0. When OpenAI changes
the event list or manifest rules, update the constants in
`validate-codex-artifact.sh` and this table together.

## Adding a domain validator

Each `validate-<domain>.sh` checks one slice of codex-dev's domain — only things
decidable by a rule (parse, field presence, enum, count, regex). Source the lib,
guard `jq`, call `add_finding <severity> <rule-id> <category> <path> <line> <msg>`
per check, end with `render_findings`. Anything requiring taste or rewriting is
**not** a script — it stays with codex-dev's skills/agents, which run `validate.sh`
and consume its JSON instead of re-deriving the rules.

> Validating codex-dev's *plugin structure* (manifest, frontmatter, layout) is
> plugin-dev's job — run plugin-dev's `validate-plugin.sh` against this repo.
> The validators here check Codex-bound artifacts.
