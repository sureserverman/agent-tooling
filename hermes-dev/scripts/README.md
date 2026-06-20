# hermes-dev — deterministic lane

This `scripts/` directory is hermes-dev's **deterministic lane**, vendored from
the plugin-dev determinism kit. It encodes one rule:

> **Mechanical, decidable checks belong in scripts. Semantic judgment belongs to
> the LLM.** Scripts flag; the model decides and writes.

## Layout

```
scripts/
├── lib/findings.sh              # shared finding accumulator + JSON contract (from plugin-dev; do not fork)
├── validate.sh                  # orchestrator — discovers and runs every validate-*.sh, merges, prints a verdict
└── validate-hermes-artifact.sh  # hermes-dev's domain validator: Hermes-Agent-bound artifact checks
```

## Usage

The target is a **Hermes-bound artifact directory** — a Hermes Python plugin,
a skills tree, or a config drop. That is usually *another* artifact, not
hermes-dev itself:

```bash
bash scripts/validate.sh <artifact-dir> [--json]
```

`--json` emits the contract (consumed by skills/agents); without it, a human
report. Exit code: `1` if any error, else `0` (`2` usage, `3` jq missing).
Requires `jq`; the YAML checks additionally need `python3` + `pyyaml` and
degrade to a warning when either is absent.

Self-test fixtures live in `tests/fixtures/`:

```bash
bash scripts/validate.sh tests/fixtures/good   # exit 0, verdict pass
bash scripts/validate.sh tests/fixtures/bad    # exit 1 — manifest fields, missing register(ctx),
                                               # Python syntax error, versionless skill, dead MCP entry
```

## What validate-hermes-artifact.sh checks (June 2026 facts, Hermes Agent v0.16.0)

| Rule id | Severity | Check |
|---|---|---|
| `hermes-plugin-yaml-parse` | error | every `plugin.yaml` parses as YAML (top level a mapping) |
| `hermes-plugin-yaml-fields` | error | plugin.yaml has non-empty `name` + `version` + `description` |
| `hermes-plugin-yaml-types` | error | `provides_tools` / `provides_hooks`, if present, are YAML **lists** |
| `hermes-plugin-register-missing` | error | a sibling `__init__.py` exists and contains `def register(` — the plugin entry point |
| `hermes-skill-frontmatter` | error | each `SKILL.md` has closed YAML frontmatter with non-empty `name` + `description` |
| `hermes-skill-no-version` | warn | frontmatter has a `version` — **required by Hermes**, not by other agentskills.io hosts, so ports routinely miss it |
| `hermes-skill-metadata` | error | `metadata.hermes`, if present, is a mapping |
| `hermes-config-parse` | error | every `config.yaml` parses as YAML |
| `hermes-config-mcp` | error | every `mcp_servers` entry has `command` (stdio) or `url` (HTTP) |
| `hermes-plugin-py-syntax` | error | every `*.py` compiles (`python3 -m py_compile`) |
| `hermes-python-missing` | warn | python3/pyyaml absent — YAML and compile checks skipped |

Scan exclusions: `.git/`, `node_modules/`, and `tests/fixtures/` (test data)
are pruned from all scans so self-scans stay clean.

Facts verified 2026-06-09 against hermes-agent.nousresearch.com/docs and
github.com/NousResearch/hermes-agent, Hermes Agent v0.16.0 "The Surface
Release" (June 5, 2026). **Hermes ships multiple minor releases per month** —
when upstream changes the manifest or frontmatter rules, update
`validate-hermes-artifact.sh` and this table together.

## Adding a domain validator

Each `validate-<domain>.sh` checks one slice of hermes-dev's domain — only things
decidable by a rule (parse, field presence, enum, count, regex). Source the lib,
guard `jq`, call `add_finding <severity> <rule-id> <category> <path> <line> <msg>`
per check, end with `render_findings`. Anything requiring taste or rewriting is
**not** a script — it stays with hermes-dev's skills/agents, which run `validate.sh`
and consume its JSON instead of re-deriving the rules.

> Validating hermes-dev's *plugin structure* (manifest, frontmatter, layout) is
> plugin-dev's job — run plugin-dev's `validate-plugin.sh` against this repo.
> The validators here check Hermes-bound artifacts.
