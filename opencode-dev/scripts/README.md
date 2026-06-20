# opencode-dev — deterministic lane

This `scripts/` directory is opencode-dev's **deterministic lane**, vendored from
the plugin-dev determinism kit. It encodes one rule:

> **Mechanical, decidable checks belong in scripts. Semantic judgment belongs to
> the LLM.** Scripts flag; the model decides and writes.

## Layout

```
scripts/
├── lib/findings.sh                 # shared finding accumulator + JSON contract (from plugin-dev; do not fork)
├── validate.sh                     # orchestrator — discovers and runs every validate-*.sh, merges, prints a verdict
└── validate-opencode-artifact.sh   # opencode-dev's domain validator: OpenCode-bound artifact checks
```

## Usage

The target is an **OpenCode-bound artifact directory** — a repo's `.opencode/`
payload, a global config dir, or a plugin/tool bundle you are about to ship.
That is usually *another* project, not opencode-dev itself:

```bash
bash scripts/validate.sh <artifact-dir> [--json]
```

`--json` emits the contract (consumed by this plugin's skills/agents); without
it, a human report. Exit code: `1` if any error, else `0` (`2` usage, `3` jq
missing).

Self-test fixtures live in `tests/fixtures/`:

```bash
bash scripts/validate.sh tests/fixtures/good   # exit 0, verdict pass
bash scripts/validate.sh tests/fixtures/bad    # exit 1 — deprecated tools: map, broken command frontmatter, singular agent/ dir, autoshare + unknown config key, export-less plugin
```

## What validate-opencode-artifact.sh checks (OpenCode v1.16, June 2026)

| Rule id | Severity | Check |
|---|---|---|
| `opencode-frontmatter` | error | every `agents/*.md` and `commands/*.md` (plural and legacy singular dirs) has parseable YAML frontmatter (python3 + pyyaml) |
| `opencode-tools-deprecated` | warn | agent frontmatter uses the deprecated `tools:` boolean map — migrate to `permission` (ask/allow/deny, bash glob maps) |
| `opencode-singular-dir` | warn | legacy singular component dirs (`agent/`, `command/`, `plugin/`, `tool/`, `skill/`, `theme/` at the root or under `.opencode/`) — plural is canonical; singular has silent-ignore bug history (issue #14410) |
| `opencode-config-parse` | error | `opencode.json` / `opencode.jsonc` parses (`//` comments stripped best-effort) |
| `opencode-config-unknown-key` | warn | every top-level config key is in the known v1.16 set — typos are silently ignored by OpenCode |
| `opencode-autoshare-deprecated` | warn | no `autoshare` boolean — replaced by `"share": "manual"\|"auto"\|"disabled"` |
| `opencode-plugin-syntax` | error | every `plugins/*.js` passes `node --check` |
| `opencode-plugin-no-export` | error | every `plugins/*.{js,ts}` is non-empty and contains an `export` — export-less plugins silently never load |
| `opencode-skill-frontmatter` | error | every `skills/*/SKILL.md` has `name` (regex `^[a-z0-9]+(-[a-z0-9]+)*$`, 1–64 chars) and `description` |

Scan exclusions: `.git/`, `node_modules/`, and `tests/fixtures/` (test data)
are skipped by every recursive scan — so running the lane against opencode-dev
itself does not trip on its own bad fixtures.

Facts verified 2026-06-09 against opencode.ai/docs/agents, /docs/commands,
/docs/plugins, /docs/config, and /docs/skills (OpenCode v1.16). When OpenCode
changes the schema or key set, update the constants at the top of
`validate-opencode-artifact.sh` and this table together.

## The JSON contract

Every `validate-*.sh`, with `--json`, prints:

```json
{"validator","target","summary":{"errors","warnings","info"},
 "findings":[{"severity":"error|warn|info","rule","category","path","line","message"}],
 "verdict":"pass|pass-with-warnings|fail"}
```

Exit code: `1` if any error, else `0` (`2` usage, `3` jq missing).

## Adding a domain validator

Each `validate-<domain>.sh` checks one slice of opencode-dev's domain — only things
decidable by a rule (parse, field presence, enum, count, regex). Source the lib,
guard `jq`, call `add_finding <severity> <rule-id> <category> <path> <line> <msg>`
per check, end with `render_findings`. Anything requiring taste or rewriting is
**not** a script — it stays with opencode-dev's skills/agents, which run `validate.sh`
and consume its JSON instead of re-deriving the rules.

> Validating opencode-dev's *plugin structure* (manifest, frontmatter, layout) is
> plugin-dev's job — run plugin-dev's `validate-plugin.sh` against this repo.
> The validators here check opencode-dev's own domain.
