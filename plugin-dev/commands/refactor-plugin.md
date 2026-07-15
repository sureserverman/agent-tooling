---
description: Refactor an existing plugin to the determinism boundary — vendor the kit, generate its domain validators, rewire its agents/commands to consume them.
argument-hint: [path-to-plugin]
allowed-tools: ["Read", "Write", "Edit", "Glob", "Grep", "AskUserQuestion", "Skill", "Agent", "Bash(bash:*)", "Bash(jq:*)", "Bash(find:*)", "Bash(cp:*)", "Bash(test:*)"]
model: inherit
---

# /refactor-plugin

Make an existing Claude Code plugin balanced the way plugin-dev is: move its
mechanical work into a deterministic bash lane (the kit), generate domain
validators for it, and rewire its agents/commands to run the scripts and consume
their JSON instead of re-deriving rules in prose.

The user invoked this command with: `$ARGUMENTS`

Let `${SCRIPTS}` mean `${CLAUDE_PLUGIN_ROOT}/scripts` below.

## Phase 0 — Load the pattern

If `$ARGUMENTS` names a plugin root, use it; otherwise ask for the path (one
`AskUserQuestion`). Confirm it has `.claude-plugin/plugin.json`.

Load the `plugin-dev:determinism-boundary` skill via the Skill tool and follow
its decision rule and `references/refactor-recipe.md` throughout.

## Phase 1 — Baseline + survey

1. Run the structural backstop and report it (must stay green at the end):

   ```bash
   bash "${SCRIPTS}/validate-plugin.sh" <target> --json
   ```

2. Read the target's skills, agents, and commands. For each, list the concrete
   checks/actions it performs and tag each into one of the **three lanes** of the
   determinism boundary (see the parent skill's decision table and
   `references/skill-to-agent.md`):

   - **mechanical** — a script decides it identically every run (→ Phase 3
     validator, or a persisted-artifact scanner if Phase 3.5 applies).
   - **judgment-interactive** — needs the user or the conversation: an interview,
     a confirm-before-assume step, an approval gate. *Stays in a skill/command* —
     a dispatched agent cannot run `AskUserQuestion`.
   - **judgment-batch-isolated** — heavy, self-contained judgment (reads many
     files/sources, fans out, or wants a cheaper pinned model). *Candidate to
     carve into a dispatched agent* in Phase 4.

   Surface the classification to the user before changing anything.

   **Extraction guard.** A judgment-batch-isolated tag is only an *invitation* to
   extract, not a mandate. Carve a skill's work into an agent only on a concrete
   benefit — context isolation, fan-out, cost (model pinning), tool-scoping, or
   reuse across skills — or it stays a skill. This is the skill→agent parallel of
   "don't invent checks just to install a kit": don't push a working, coupled
   skill into an agent for tidiness.

If the target does no mechanical domain work **and** no batch judgment worth
isolating (a pure interactive-judgment plugin), say so and stop — don't invent
checks just to install a kit, and don't carve agents with no concrete benefit.

## Phase 2 — Vendor the kit

```bash
bash "${SCRIPTS}/install-kit.sh" <target>
```

Drops `lib/findings.sh`, `validate.sh`, and a boundary `scripts/README.md` into
the target. Idempotent; never touches the target's own validators.

## Phase 3 — Generate domain validators (full)

Group the mechanical checks into a few cohesive domains (by the artifact they
inspect). For each:

```bash
bash "${SCRIPTS}/scaffold-validator.sh" <target>/scripts <domain>
```

Then replace the stub's TODO with the **real** checks — parse the target's actual
configs and assert its real invariants on the shared contract (`add_finding`).
Severity discipline: hard violations `error`, shoulds `warn`, regex candidates
`warn`, nudges `info`. Prove each fires against a deliberately broken fixture.

## Phase 3.5 — Persisted-artifact schemas + depth tiers (conditional)

Two conditional passes, each keyed to what the Phase 1 survey found. **Both are
skippable** — run a pass only when its trigger is present, and say so when you
skip.

**Persisted artifacts.** If the target has a skill that writes a *structured
document a consumer reads back* (a report, a plan, an assessment — not inline
output), give that artifact the deterministic treatment per
`references/tiered-artifacts.md`: stamp a **schema version** on the artifact and
its format doc, add a **scanner** (`validate-<artifact>.sh`, or a small
`<artifact>-scan.py` where the parse exceeds bash) with per-artifact/per-tier
ceilings on the shared findings contract, and commit **fixtures** — at least one
happy artifact and one deliberately-broken one per check — proving each check
fires. *Skip if the target persists nothing structured* (most plugins) — don't
invent a persisted format just to scan it.

**Depth tiers.** If a target skill's effort can vary by roughly an order of
magnitude with scope (research, report generation, a registry/portfolio sweep),
give it depth tiers per `references/depth-tiers.md`: ask the tier first (one
`AskUserQuestion`, in the skill), confirm scope before assuming, record the tier
in the artifact, and pass it as the dispatch parameter to any agent extracted in
Phase 4. *Skip for a skill whose effort barely varies* (~2–3x) — a tier menu on a
bounded skill is ceremony.

## Phase 4 — Rewire the judgment lane

Edit the target's agents/commands to **run the scripts and consume JSON** rather
than re-derive rules. Mirror plugin-dev's `agents/plugin-validator.md`: run
`scripts/validate.sh <root> --json`, report findings verbatim, then add only the
judgment layer. Strip the now-duplicated mechanical prose; add `Bash(bash:*)` to
`allowed-tools` where a command needs to run the lane. For write-heavy edits,
dispatch the `agent-creator` agent or edit inline as appropriate.

**Extract the batch-isolated tags into agents.** For each Phase 1 action tagged
*judgment-batch-isolated* that cleared the extraction guard, carve it out of its
skill into a dispatched agent (per `references/skill-to-agent.md`): dispatch
`agent-creator` to author the agent, pin it to the smallest model that can do the
job, and rewrite the skill to keep the interactive parts (interview, scope
confirm) in the main loop and dispatch the agent for the batch work — passing any
chosen depth tier as the agent's dispatch parameter. Leave a tag in place as a
skill if it failed the guard; note why.

## Phase 5 — Document + gate

1. Specialize the vendored `scripts/README.md` to the target's real domains; add
   a short "Determinism boundary" note to the target's README and relevant SKILLs.
2. Both gates must pass:

   ```bash
   bash <target>/scripts/validate.sh <target>          # the target's own domain lane
   bash "${SCRIPTS}/validate-plugin.sh" <target>        # structure, still green
   ```

3. Show the user: new `scripts/` tree, the validators added, what was rewired,
   and both verdicts. Bump the target's version; leave commits/push to the user.

## Anti-patterns to refuse

- Vendoring plugin-dev's *structural* validators into the target (structure stays
  plugin-dev's external job).
- A domain validator that judges quality or rewrites content (wrong lane).
- Forking `lib/findings.sh` (refresh with `install-kit.sh --force`).
- Leaving mechanical prose in an agent after its checks became a script.
