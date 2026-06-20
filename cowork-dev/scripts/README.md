# cowork-dev — deterministic lane

This `scripts/` directory is cowork-dev's **deterministic lane**, vendored from
the plugin-dev determinism kit. It encodes one rule:

> **Mechanical, decidable checks belong in scripts. Semantic judgment belongs to
> the LLM.** Scripts flag; the model decides and writes.

## Layout

```
scripts/
├── lib/findings.sh              # shared finding accumulator + JSON contract (from plugin-dev; do not fork)
├── validate.sh                  # orchestrator — discovers and runs every validate-*.sh, merges, prints a verdict
└── validate-cowork-artifact.sh  # cowork-dev's domain validator: Cowork-bound package checks
```

## Usage

The target is a **Cowork-bound plugin package directory** — the directory you
are about to ZIP for upload or expose through a marketplace. That is usually
*another* plugin, not cowork-dev itself:

```bash
bash scripts/validate.sh <package-dir> [--json]
```

`--json` emits the contract (consumed by skills/agents); without it, a human
report. Exit code: `1` if any error, else `0` (`2` usage, `3` jq missing).

Self-test fixtures live in `tests/fixtures/`:

```bash
bash scripts/validate.sh tests/fixtures/good   # exit 0, verdict pass
bash scripts/validate.sh tests/fixtures/bad    # exit 1 — reserved name, stdio MCP, npm source
```

## What validate-cowork-artifact.sh checks (June 2026 limits)

| Rule id | Severity | Check |
|---|---|---|
| `cowork-manifest-missing` / `cowork-manifest-unparseable` | error | `.claude-plugin/plugin.json` exists and parses |
| `cowork-name-missing` | error | manifest has a `name` |
| `cowork-name-not-lowercase-hyphen` | error | name is lowercase letters / digits / hyphens |
| `cowork-name-too-long` | error | name ≤64 chars |
| `cowork-name-reserved` | error | name not on Cowork's reserved list (`claude-code-marketplace`, `anthropic-plugins`, `agent-skills`, …) |
| `cowork-package-too-large` | error | uncompressed package ≤200 MB |
| `cowork-package-size-near-limit` | warn | over 80% of the 200 MB cap |
| `cowork-package-too-many-files` | error | ≤5,000 files |
| `cowork-package-file-count-near-limit` | warn | over 80% of the 5,000-file cap |
| `cowork-marketplace-npm-pip-source` | error | no npm/pip plugin sources in any marketplace.json (unsupported in Cowork org marketplaces) |
| `cowork-marketplace-unparseable` | warn | marketplace.json parses (broken manifests fail org sync) |
| `cowork-mcp-stdio` | error | no local stdio MCP servers (`command` key) in the package's root `.mcp.json` — Cowork supports MCP only via cloud connectors |
| `cowork-mcp-unparseable` | warn | `.mcp.json` parses |

Scan exclusions: `.git/` is excluded from size/file counts (not part of the
ZIP); `.git/`, `node_modules/`, and `tests/fixtures/` are skipped by the
marketplace.json scan (test data). The stdio-MCP check reads only the package
root `.mcp.json` — the only one Cowork would load.

Facts verified 2026-06-09 against claude.com/docs/cowork/guide/plugins and
support.claude.com articles 13837440 + 13837433. When Anthropic changes the
limits, update the constants at the top of `validate-cowork-artifact.sh` and
this table together.

## Adding a domain validator

Each `validate-<domain>.sh` checks one slice of cowork-dev's domain — only things
decidable by a rule (parse, field presence, enum, count, regex). Source the lib,
guard `jq`, call `add_finding <severity> <rule-id> <category> <path> <line> <msg>`
per check, end with `render_findings`. Anything requiring taste or rewriting is
**not** a script — it stays with cowork-dev's skills, which run `validate.sh`
and consume its JSON instead of re-deriving the rules.

> Validating cowork-dev's *plugin structure* (manifest, frontmatter, layout) is
> plugin-dev's job — run plugin-dev's `validate-plugin.sh` against this repo.
> The validators here check Cowork-bound packages.
