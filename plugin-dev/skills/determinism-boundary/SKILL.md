---
name: determinism-boundary
description: Use when deciding which plugin work belongs in deterministic scripts versus LLM judgment, giving a plugin its own deterministic lane, or making a plugin balanced the way plugin-dev is. Triggers on "determinism boundary", "script vs judgment split", "add a deterministic lane", "make this plugin self-validating", "deterministic scripts vs LLM", "refactor plugin to use scripts".
---

# determinism-boundary

The design rule plugin-dev applies to itself, and the pattern for giving any
plugin the same balance: **mechanical, decidable work goes in deterministic bash
scripts; judgment stays with the LLM, which runs the scripts and consumes their
output instead of re-deriving the rules in prose.**

Use this when authoring a new plugin's deterministic lane (via `/create-plugin`)
or refactoring an existing one (via `/refactor-plugin`). For the full brownfield
walk-through, read `references/refactor-recipe.md`.

## Which lane does a check belong in?

Decide per check. The test: *could a script decide this the same way every time?*

| Goes in a **script** (deterministic) | Stays with the **LLM** (judgment) |
|---|---|
| Parse a file (JSON/YAML/TOML); does it parse? | Is this design coherent / well-scoped? |
| Required field present; value in an enum/whitelist | Is this description's wording going to trigger? |
| Name matches a path; kebab-case; semver | Confirm a flagged leak/POV and *rewrite* it |
| Counts and bounds (line/char limits, ranges) | Prompt-injection risk in ingested content |
| Regex presence/absence (hardcoded paths, secrets, guards) | Tool-set minimalism; model-tier fit |
| Cross-file consistency (declared vs on-disk) | Writing component bodies / domain content |

Two consequences to internalize:

- **Regex only flags candidates.** A script can spot a numbered list in a
  `description:`; whether that is a real leak and how to fix it without losing
  the trigger is the model's call. Emit such checks at `warn`, not `error`.
- **Scripts never edit.** They read, decide, report. Mutation (scaffolding) is a
  separate, explicit family of scripts.

A plugin's *own* domain checks (does its Cargo.toml parse, are its i18n catalogs
in sync) are deterministic and belong in **that plugin's** scripts. Validating
plugin *structure* (manifest, frontmatter, layout) is plugin-dev's job — run
plugin-dev's `validate-plugin.sh` from outside; don't re-implement it.

## The deterministic lane (the kit)

A plugin's deterministic lane lives in its `scripts/`, vendored from plugin-dev:

```
scripts/
├── lib/findings.sh       # shared finding accumulator + JSON contract (do not fork)
├── validate.sh           # orchestrator: discovers + runs every validate-*.sh, merges, verdicts
└── validate-<domain>.sh  # the plugin's own domain validators
```

Install it with `install-kit.sh <plugin-root>`; add a validator with
`scaffold-validator.sh <scripts-dir> <domain>`. Both are in plugin-dev's
`scripts/`. The JSON contract and rule-id conventions are documented in
plugin-dev's `scripts/README.md` — that is the source of truth; don't restate it.

## Authoring a domain validator

`scaffold-validator.sh` gives you a stub on the contract. Fill only decidable
checks: source the lib, `have_jq`, one `add_finding <severity> <rule-id>
<category> <relpath> <line|0> "<message>"` per check, end with `render_findings`.
Keep rule-ids stable and kebab-case — the plugin's agents key off them. If a
would-be check needs taste or rewriting, it is not a script; leave it to a skill
or agent.

## Rewiring the judgment lane to consume scripts

Once the deterministic lane exists, the plugin's agents and commands must **stop
re-deriving mechanical rules in prose** and instead:

1. Run `scripts/validate.sh <root> --json` (or a specific `validate-<domain>.sh`).
2. Report its findings verbatim (they are authoritative).
3. Add only the judgment layer on top — confirm candidates, assess design.

plugin-dev's own `agents/plugin-validator.md` is the canonical shape: run the
script, report it, add judgment. Mirror it.

## Anti-patterns

- A skill/agent listing structural rules it "checks" in prose — those are a script's job.
- A domain validator that tries to judge quality or rewrite — wrong lane.
- Forking `lib/findings.sh` per plugin — it is copied verbatim; refresh with `install-kit.sh --force`.
- Promoting a regex *candidate* (leak/POV heuristic) to `error` — keep it `warn` for the LLM to confirm.
