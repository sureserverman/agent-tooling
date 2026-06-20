# cursor-dev — deterministic lane

This `scripts/` directory is cursor-dev's **deterministic lane**, vendored from
the plugin-dev determinism kit. It encodes one rule:

> **Mechanical, decidable checks belong in scripts. Semantic judgment belongs to
> the LLM.** Scripts flag; the model decides and writes.

## Layout

```
scripts/
├── lib/findings.sh              # shared finding accumulator + JSON contract (from plugin-dev; do not fork)
├── validate.sh                  # orchestrator — discovers and runs every validate-*.sh, merges, prints a verdict
└── validate-cursor-artifact.sh  # cursor-dev's domain validator: Cursor-bound artifact checks
```

## Usage

The target is a **Cursor-bound artifact directory** — a Cursor plugin you are
about to publish, or a repo's `.cursor/` payload. That is usually *another*
plugin, not cursor-dev itself:

```bash
bash scripts/validate.sh <artifact-dir> [--json]
```

`--json` emits the contract (consumed by this plugin's skills/agents); without
it, a human report. Exit code: `1` if any error, else `0` (`2` usage, `3` jq
missing).

Self-test fixtures live in `tests/fixtures/`:

```bash
bash scripts/validate.sh tests/fixtures/good   # exit 0, verdict pass
bash scripts/validate.sh tests/fixtures/bad    # exit 1 — ignored .md rule, broken .mdc, skill name mismatch, hooks version + PascalCase event
```

## What validate-cursor-artifact.sh checks (Cursor 3.7, June 2026)

| Rule id | Severity | Check |
|---|---|---|
| `cursor-manifest-missing` / `cursor-manifest-unparseable` | error | `.cursor-plugin/plugin.json` exists and parses (note: NOT `.claude-plugin/`) |
| `cursor-manifest-name-missing` | error | manifest has a `name` — the only required field |
| `cursor-mdc-frontmatter` | error | every `rules/*.mdc` has parseable YAML frontmatter (python3 + pyyaml) |
| `cursor-rule-manual-only` | warn | `alwaysApply: false` with no `description` and no `globs` — accidental manual-only rule that never auto-applies |
| `cursor-rules-md-ignored` | error | no plain `.md` files inside a `rules/` dir — Cursor only loads `.mdc` and silently ignores the rest |
| `cursor-skill-name-mismatch` | error | every `skills/*/SKILL.md` frontmatter `name` equals its directory name |
| `cursor-hooks-unparseable` | error | `hooks.json` (if present) parses |
| `cursor-hooks-version` | error | `hooks.json` has an integer top-level `version` field |
| `cursor-hook-unknown-event` | warn | every hook event name is in Cursor's known camelCase set (~22 events) — PascalCase ported from Claude Code is the usual offender |

Scan exclusions: `.git/`, `node_modules/`, and `tests/fixtures/` (test data)
are skipped by every recursive scan — so running the lane against cursor-dev
itself does not trip on its own bad fixtures.

Facts verified 2026-06-09 against cursor.com/docs/plugins,
/docs/context/rules, /docs/skills, and /docs/hooks.md (Cursor 3.7). When
Cursor changes the schema or event set, update the constants at the top of
`validate-cursor-artifact.sh` and this table together.

## The JSON contract

Every `validate-*.sh`, with `--json`, prints:

```json
{"validator","target","summary":{"errors","warnings","info"},
 "findings":[{"severity":"error|warn|info","rule","category","path","line","message"}],
 "verdict":"pass|pass-with-warnings|fail"}
```

Exit code: `1` if any error, else `0` (`2` usage, `3` jq missing).

## Adding a domain validator

Each `validate-<domain>.sh` checks one slice of cursor-dev's domain — only things
decidable by a rule (parse, field presence, enum, count, regex). Source the lib,
guard `jq`, call `add_finding <severity> <rule-id> <category> <path> <line> <msg>`
per check, end with `render_findings`. Anything requiring taste or rewriting is
**not** a script — it stays with cursor-dev's skills/agents, which run `validate.sh`
and consume its JSON instead of re-deriving the rules.

> Validating cursor-dev's *plugin structure* (manifest, frontmatter, layout) is
> plugin-dev's job — run plugin-dev's `validate-plugin.sh` against this repo.
> The validators here check cursor-dev's own domain.
