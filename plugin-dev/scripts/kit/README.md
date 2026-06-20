# __PLUGIN__ — deterministic lane

This `scripts/` directory is __PLUGIN__'s **deterministic lane**, vendored from
the plugin-dev determinism kit. It encodes one rule:

> **Mechanical, decidable checks belong in scripts. Semantic judgment belongs to
> the LLM.** Scripts flag; the model decides and writes.

## Layout

```
scripts/
├── lib/findings.sh      # shared finding accumulator + JSON contract (from plugin-dev; do not fork)
├── validate.sh          # orchestrator — discovers and runs every validate-*.sh, merges, prints a verdict
└── validate-<domain>.sh # __PLUGIN__'s own domain validators (you add these)
```

Run the whole lane:

```bash
bash scripts/validate.sh <plugin-root> [--json]
```

`--json` emits the contract (consumed by this plugin's agents/commands); without
it, a human report.

## The JSON contract

Every `validate-*.sh`, with `--json`, prints:

```json
{"validator","target","summary":{"errors","warnings","info"},
 "findings":[{"severity":"error|warn|info","rule","category","path","line","message"}],
 "verdict":"pass|pass-with-warnings|fail"}
```

Exit code: `1` if any error, else `0` (`2` usage, `3` jq missing).

## Adding a domain validator

Each `validate-<domain>.sh` checks one slice of __PLUGIN__'s domain — only things
decidable by a rule (parse, field presence, enum, count, regex). Source the lib,
guard `jq`, call `add_finding <severity> <rule-id> <category> <path> <line> <msg>`
per check, end with `render_findings`. Anything requiring taste or rewriting is
**not** a script — it stays with __PLUGIN__'s skills/agents, which run `validate.sh`
and consume its JSON instead of re-deriving the rules.

> Validating __PLUGIN__'s *plugin structure* (manifest, frontmatter, layout) is
> plugin-dev's job — run plugin-dev's `validate-plugin.sh` against this repo.
> The validators here check __PLUGIN__'s own domain.
