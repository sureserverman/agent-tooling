# The skill lifecycle

plugin-dev covers a skill across its whole life, not just its birth. Four
capabilities form a loop — **discover → build → measure → maintain** — so a
skills estate stays useful instead of quietly rotting into overlapping,
half-remembered files.

```
skill-workshop / scan-sessions   →  discover candidates worth building   (BIRTH)
skill-development                 →  write the SKILL.md
skill-eval  + skill-judge         →  prove it works, gate rewrites        (MEASURE)
skill-curator                     →  retire what has gone stale           (DECAY)
```

The design is adapted from Nous Research's Hermes Agent (its Curator, its GEPA
eval pipeline, and its skill-creation triggers), reshaped to plugin-dev's
determinism boundary: mechanical, decidable work lives in deterministic shell
scripts; judgment lives in skills (interactive) and agents (batch, model-pinned).

> **Invocation.** `skill-curator` and `skill-eval` are **explicit-invocation
> only** (`disable-model-invocation: true`) — they don't fire on their own
> mid-task, because one archives files and the other spends tokens. You start
> them with a slash command or by asking directly. `skill-workshop` is the same.

---

## 1. Discover — trigger heuristics (birth)

`skill-workshop` (this plugin) and `obsidian-wiki:scan-sessions` mine your
session history for things worth turning into a skill. Every candidate is now
classified by **why** it is worth capturing — one of four canonical triggers
(the exact same label strings in both tools, so they stay in sync):

| Trigger | What it means | Strength |
|---|---|---|
| `user-correction` | you corrected the agent's approach and the corrected approach then worked | strongest — a correction is direct evidence a skill was missing |
| `error-resolved` | an error was resolved through visible trial-and-error (≥2 failed attempts) | strong — a hard-won fix worth not rediscovering |
| `nonobvious-workflow` | a working procedure that needed discovery/lookup, not derivation | medium |
| `recurring-toolchain` | the same 5+ tool sequence you keep re-driving by hand | weakest alone — repetition ≠ a missing skill |

Candidates are grouped and ranked by trigger, `user-correction` and
`error-resolved` first, so the top suggestions are the ones most likely to be
real gaps.

**Use it:** run `skill-workshop` (`/plugin-dev:skill-workshop [project-path]`)
to mine a project's Claude Code history, or `/obsidian-wiki:scan-sessions` to
sweep all five AI tools for vault-worthy sessions. The `session-analyzer` Haiku
agent does the extraction; `skill-workshop` presents candidates and drafts
SKILL.md files for the ones you approve.

The detection recipes and the output schema (each candidate carries a `trigger`
field) live in [`agents/session-analyzer.md`](../agents/session-analyzer.md).

---

## 2. Build — `skill-development`

Unchanged, and still the tool for authoring a SKILL.md correctly (frontmatter,
leak-safe description, progressive disclosure). See the `skill-development`
skill. What's new is that you can now *measure* whether the result actually
helps.

---

## 3. Measure — `skill-eval` + `skill-judge`

`skill-eval` answers "does this skill actually help, or does it just look nice?"
It runs a skill against a set of eval cases and has a **separate** model grade
each result against a rubric — a skill can't grade its own homework (the core
GEPA insight: an executor tends to congratulate itself).

**How a run goes:**

1. **Mechanical gate first, before any token spend.** `skill-eval-gate.sh
   precheck` rejects a SKILL.md over 15 KB, an invalid eval set, or a missing
   description — so a skill that fails a cheap check never dispatches anything.
2. **Run each case.** One case-runner subagent per case plays the skill against
   the case prompt and produces a transcript.
3. **Judge each transcript.** The `skill-judge` agent (Sonnet, read-only) scores
   the rubric criterion-by-criterion **with evidence**, and is forbidden from
   emitting a bare pass/fail — the rubric scores are the whole verdict.
4. **Verdict.** `skill-eval-gate.sh verdict` applies the thresholds
   (`min_case_score`, `pass_fraction`). A case with **no** score counts as a
   fail, never a silent pass.

**Gating a rewrite (the highest-value mode).** Before changing a skill, score it
(`baseline`); after, score the candidate; then
`skill-eval-gate.sh compare baseline.json candidate.json` accepts the rewrite
**only if it holds or beats the baseline on every case** — an improvement in one
area can never pay for a regression in another. Full protocol:
[`skills/skill-eval/references/rewrite-loop.md`](../skills/skill-eval/references/rewrite-loop.md).

**Use it:** `/plugin-dev:skill-eval` and point it at a skill. If the skill has no
eval set yet, it offers to draft one — `evalset-mine.sh` pulls real cases from
sessions where the skill actually fired (leaving `TODO` rubric stubs for you to
finish), and you add synthetic/golden cases by hand. Eval-set format:
[`skills/skill-eval/references/evalset-format.md`](../skills/skill-eval/references/evalset-format.md).

### The one thing to know before you write eval cases

An eval only discriminates skill quality if its cases test value the skill
**uniquely** provides. A case that tests *general* competence ("write valid
frontmatter", "spot a description leak") will pass even against a **deleted**
skill — because a capable model already knows how. Write cases around your
skill's *specific* value: a project convention, an exact required token, a
non-obvious step. Those are the cases that actually drop when the skill is
degraded. (This was confirmed empirically while building the harness — gutting a
general-knowledge skill still scored 5/5; only a skill-specific case fell to
0/5.) The format doc's "Writing cases that actually discriminate" section says
more.

---

## 4. Maintain — `skill-curator` (decay)

Without upkeep, agent-created and hand-written skills pile up into overlapping,
token-expensive clutter. `skill-curator` is the spring-cleaning pass. Run it
every month or two.

**What it does:** a deterministic scan classifies every skill in your estate —

- `fresh` (used < 30 days ago), `stale` (30–90d), `archive-candidate` (≥ 90d),
  `pinned`, or `report-only`.
- "Used" comes from your session history (last time the skill was invoked); when
  history has none (Claude Code prunes old sessions), it falls back to file
  mtime and marks the evidence weaker — so a skill is never wrongly retired just
  because its usage aged out of history.

Then it walks you through each stale/archive-candidate **personal** skill and
asks: **keep** (optionally pin), **patch**, **consolidate** into another, or
**archive**.

**Safety rules (some enforced in code, not just prose):**

- **Nothing is ever deleted.** *Code-enforced* — the archive script has no delete
  verb. Archiving moves a skill into `~/.claude/skills/.archive/`, restorable
  with one `restore`. A tar.gz snapshot of the whole estate is taken before the
  first change.
- **Pinned skills are never archived.** *Code-enforced* — the archive script
  reads `.curator-pins` and refuses a pinned slug even if asked. Pin one with the
  skill's pin sub-flow; it stays exempt from archival but still patchable.
- **Plugin/marketplace skills are report-only.** Git-managed skills are surfaced
  but never touched (this is procedural — the curator only ever mutates your
  personal `~/.claude/skills`).
- **Re-propagate reminder.** If you mirror personal skills to other tools with
  `propagate-skill-across-ide-repos`, the curator reminds you to re-run it after
  an archive so a mirror doesn't resurrect the skill.

**Use it:** `/plugin-dev:skill-curator`. To undo, `curator-archive.sh list` then
`curator-archive.sh restore <slug>`; for a full rollback, untar the pre-run
snapshot under `.archive/snapshots/`.

---

## The deterministic lane

Every mechanical part of the lifecycle is a plain, reproducible shell script that
emits the shared findings/data contract — the LLM only does the judgment:

| Script | Role |
|---|---|
| `curator-inventory.sh` / `curator-usage.sh` / `curator-scan.sh` | read-only estate enumeration, last-triggered extraction, lifecycle state machine |
| `curator-archive.sh` | the only mutating curator script — move-only snapshot / archive / restore |
| `validate-curator.sh` | validates the curator's runtime artifacts (`.curator-pins`, `.archive/` layout) |
| `validate-evalset.sh` | validates a `cases.yaml` eval set |
| `evalset-mine.sh` | drafts session eval cases (consumes `curator-usage.sh` — single source, no fork) |
| `skill-eval-gate.sh` | mechanical precheck / threshold verdict / rewrite comparison |

Re-runnable coverage: `tests/curator-tests.sh` and `tests/evalset-tests.sh`.
