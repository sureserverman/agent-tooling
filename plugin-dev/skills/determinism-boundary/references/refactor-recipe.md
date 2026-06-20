# Refactor recipe — make an existing plugin balanced

The brownfield walk-through for taking a plugin that does mechanical work via
LLM prose and giving it a deterministic lane, the way plugin-dev was refactored.
`/refactor-plugin <path>` drives this; the steps are here for reference.

## 0. Baseline

Run plugin-dev's structural validator on the target and record the result — it is
the structural backstop and must stay green:

```bash
bash "${CLAUDE_PLUGIN_ROOT}/scripts/validate-plugin.sh" <target> --json
```

## 1. Survey what the target actually does

Read the target's skills, agents, and commands. For each, list the concrete
checks/actions it performs. Tag each as **mechanical** (a script could decide it
identically every run) or **judgment** (needs taste, rewriting, or design sense),
using the decision table in the parent SKILL.

Look hardest at:
- Agents/commands that enumerate "I check that X, Y, Z…" in prose — those Xs are
  usually scripts.
- Any parsing, field-presence, enum, count, regex, or cross-file consistency the
  prose asks the model to perform by hand.

## 2. Group mechanical work into domains

Cluster the mechanical checks by the artifact they inspect — one `validate-<domain>.sh`
per coherent slice of the plugin's domain (e.g. `manifest`, `catalog`, `config`,
`recipe`). Aim for a few cohesive validators, not one per check.

## 3. Vendor the kit

```bash
bash "${CLAUDE_PLUGIN_ROOT}/scripts/install-kit.sh" <target>
```

This drops `lib/findings.sh`, `validate.sh`, and a boundary `scripts/README.md`
into the target. It is idempotent; the target's own validators are never touched.

## 4. Generate each domain validator (full)

For each domain from step 2:

```bash
bash "${CLAUDE_PLUGIN_ROOT}/scripts/scaffold-validator.sh" <target>/scripts <domain>
```

Then replace the stub's TODO with the **real** checks — parse the target's actual
configs and assert its real invariants — emitting `add_finding` on the shared
contract. Severity discipline: hard rule violations are `error`, shoulds are
`warn`, regex *candidates* are `warn`, nudges are `info`. Confirm each fires by
running it against a deliberately broken fixture.

## 5. Rewire the judgment lane

Edit the target's agents/commands so they **run the scripts and consume JSON**
instead of re-deriving rules:

- An agent that was a prose checklist → "run `scripts/validate.sh <root> --json`,
  report findings verbatim, then add the judgment layer." (Mirror plugin-dev's
  `agents/plugin-validator.md`.)
- A command that hand-validated → call `scripts/validate.sh` as a gate, then do
  the semantic work.

Strip the now-duplicated mechanical prose. Add the tool permission for running
the scripts (`Bash(bash:*)`) where needed.

## 6. Document the boundary

Specialize the vendored `scripts/README.md` to the target's real domains, and add
a short "Determinism boundary" note to the target's top-level README and the
relevant SKILLs (which checks are script-owned vs judgment).

## 7. Gate

Both must pass before you are done:

```bash
bash <target>/scripts/validate.sh <target>            # the target's own domain lane
bash "${CLAUDE_PLUGIN_ROOT}/scripts/validate-plugin.sh" <target>   # structure, still green
```

## Notes

- Don't vendor plugin-dev's structural validators into the target — structure
  validation stays plugin-dev's external job.
- If the target has no mechanical domain work at all (pure-judgment plugin),
  installing the kit is optional; say so rather than inventing checks.
- Keep `lib/findings.sh` unforked; refresh with `install-kit.sh --force`.
