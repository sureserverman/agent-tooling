# openclaw-dev — deterministic lane

This `scripts/` directory is openclaw-dev's **deterministic lane**, vendored from
the plugin-dev determinism kit. It encodes one rule:

> **Mechanical, decidable checks belong in scripts. Semantic judgment belongs to
> the LLM.** Scripts flag; the model decides and writes.

## Layout

```
scripts/
├── lib/findings.sh                # shared finding accumulator + JSON contract (from plugin-dev; do not fork)
├── validate.sh                    # orchestrator — discovers and runs every validate-*.sh, merges, prints a verdict
└── validate-openclaw-artifact.sh  # openclaw-dev's domain validator: OpenClaw-bound artifact checks
```

## Usage

The target is an **OpenClaw-bound artifact directory** — a plugin package, a
skills tree, a hooks tree, or a config drop. That is usually *another*
artifact, not openclaw-dev itself:

```bash
bash scripts/validate.sh <artifact-dir> [--json]
```

`--json` emits the contract (consumed by skills/agents); without it, a human
report. Exit code: `1` if any error, else `0` (`2` usage, `3` jq missing).
Requires `jq`; the openclaw.json JSON5 check additionally needs `python3`
(uses the `json5` module when installed, otherwise a best-effort
strip-comments-and-trailing-commas pass) and degrades to a warning when
python3 is absent.

Self-test fixtures live in `tests/fixtures/`:

```bash
bash scripts/validate.sh tests/fixtures/good   # exit 0, verdict pass
bash scripts/validate.sh tests/fixtures/bad    # exit 1 — id-less manifest, missing openclaw
                                               # field, multi-line metadata YAML, handler-less
                                               # hook, root-barrel import
```

## What validate-openclaw-artifact.sh checks (June 2026 facts, OpenClaw 2026.6.5)

| Rule id | Severity | Check |
|---|---|---|
| `openclaw-plugin-manifest` | error | every `openclaw.plugin.json` parses and has an `id` |
| `openclaw-package-field` | error | a sibling `package.json` exists and carries the `openclaw` field — OpenClaw plugins require BOTH manifests |
| `openclaw-extensions-missing` | error | every `package.json` `openclaw.extensions` path resolves to an existing file |
| `openclaw-sdk-root-barrel` | warn | no `*.ts` imports of the exact root barrel `openclaw/plugin-sdk` — DEPRECATED; use focused subpaths (`plugin-entry`, `channel-core`, `tool-plugin` ≥2026.5.17) |
| `openclaw-skill-frontmatter` | error | each `*/SKILL.md` has closed YAML frontmatter with non-empty `name` + `description` |
| `openclaw-skill-metadata-json` | error | a frontmatter `metadata:` value, if present, is **single-line JSON parseable by jq** — the signature OpenClaw check; nested YAML blocks are not read |
| `openclaw-hook-handler-missing` | error | every directory containing `HOOK.md` also contains `handler.ts` |
| `openclaw-hook-events` | error | `HOOK.md` frontmatter parses and `metadata.openclaw.events` (legacy `metadata.clawdbot.events` accepted) is a non-empty list |
| `openclaw-config-parse` | error | every `openclaw.json` passes a JSON5-ish parse (//-comments + trailing commas stripped best-effort; `json5` module used when available) |
| `openclaw-python-missing` | warn | python3 absent — openclaw.json parse check skipped |

Scan exclusions: `.git/`, `node_modules/`, and `tests/fixtures/` (test data) are
pruned from every scan so self-scans stay clean.

Facts verified 2026-06-09 against docs.openclaw.ai (tools/skills,
tools/creating-skills, tools/plugin, plugins/building-plugins, automation,
gateway/configuration), OpenClaw 2026.6.5. When upstream changes the manifest
or metadata rules, update `validate-openclaw-artifact.sh` and this table
together.

## Adding a domain validator

Each `validate-<domain>.sh` checks one slice of openclaw-dev's domain — only things
decidable by a rule (parse, field presence, enum, count, regex). Source the lib,
guard `jq`, call `add_finding <severity> <rule-id> <category> <path> <line> <msg>`
per check, end with `render_findings`. Anything requiring taste or rewriting is
**not** a script — it stays with openclaw-dev's skills, which run `validate.sh`
and consume its JSON instead of re-deriving the rules.

> Validating openclaw-dev's *plugin structure* (manifest, frontmatter, layout) is
> plugin-dev's job — run plugin-dev's `validate-plugin.sh` against this repo.
> The validators here check OpenClaw-bound artifacts.
