---
name: skill-eval
description: Use to evaluate whether a skill actually works — run its eval cases, judge them against rubrics with a separate model, and gate on hard thresholds. Triggers on "evaluate this skill", "does this skill work", "score my skill", "skill eval", "test skill effectiveness".
disable-model-invocation: true
allowed-tools: Bash, Read, Write, Task, AskUserQuestion, Grep, Glob
---

# Skill Eval

Measure whether a skill does its job, GEPA-style: run each eval case, have a
**separate** model judge the result against a rubric, and gate on hard
thresholds. The premise is that a skill's own executor is a biased judge of its
success — so evaluation is independent and evidence-based, never a self-report.

Scripts: `${CLAUDE_PLUGIN_ROOT}/scripts/`. The deterministic gates and threshold
arithmetic live in `skill-eval-gate.sh`; the judging lives in the `skill-judge`
agent.

## Step 1 — Locate the skill and its eval set

The target skill is `<name>`; its eval set is `<skill-dir>/evals/cases.yaml`
(format: `references/evalset-format.md`). If none exists, offer to build one:

- `bash "${CLAUDE_PLUGIN_ROOT}/scripts/evalset-mine.sh" <name>` drafts
  `source: session` cases from real history (rubrics come back as `TODO` stubs —
  fill them in with the user).
- Add `synthetic` and `golden` cases by hand for behaviors history doesn't cover.

## Step 2 — Mechanical gates FIRST (before any API spend)

Run the cheap deterministic gate before dispatching anything:

```bash
bash "${CLAUDE_PLUGIN_ROOT}/scripts/skill-eval-gate.sh" precheck \
  <skill-dir> <skill-dir>/evals/cases.yaml --json
```

It enforces: SKILL.md ≤ 15 KB, a valid (non-draft) eval set, and a present
description. **If it reports any error, STOP** — fix the skill/eval set and
re-run. Do not dispatch case-runners or judges; the whole point of gating here is
to spend zero tokens on a skill that fails a mechanical check.

Then run the judgment gate that a script can't: invoke the
`skill-description-leak-audit` skill on the skill's description. A leak is a gate
failure — surface it before proceeding.

## Step 3 — Run each case (case-runners)

For each case in `cases.yaml`, dispatch one subagent (via Task) that plays the
skill against the case `prompt`, with the **candidate skill's content in
context**. Capture its full transcript. These runs are independent — they may go
concurrently. A case-runner must not judge itself; it only produces the
transcript.

## Step 4 — Judge each transcript (skill-judge)

For each transcript, dispatch the `skill-judge` agent (Task) with the case
`rubric`, the case `prompt`, and the transcript. It returns
`{case_id, criteria:[{name,score,evidence}], weighted_total}` — rubric scores
with evidence, never a bare pass/fail. Collect all of these into a scores array:

```json
[{"case_id":"…","weighted_total":4.5}, …]
```

Write it to a scratch file (e.g. `/tmp/skill-eval-scores.json`).

## Step 5 — Verdict

```bash
bash "${CLAUDE_PLUGIN_ROOT}/scripts/skill-eval-gate.sh" verdict \
  <skill-dir>/evals/cases.yaml /tmp/skill-eval-scores.json
```

It applies `min_case_score` and `pass_fraction` and returns
`{verdict, pass_fraction_actual, cases:[…], failed:[…]}`. Present a table:
per-case weighted score vs the minimum, which passed, and the overall verdict.
Show the judge's per-criterion evidence for any failed case so the result is
actionable, not just a number.

## Step 6 — Judgment gates surface as questions

Some gates need a human, not a script — most importantly **purpose drift**: has
the skill's description or scope wandered from what it is supposed to do? When you
suspect drift (e.g. the precheck flagged `evalgate-desc-drift` against a
baseline), raise it with AskUserQuestion rather than passing silently.

## Evaluating a rewrite

To check that a rewrite (from `stingy-agents:skill-rewriter` or by hand) didn't
regress the skill, use the baseline comparison in
`references/rewrite-loop.md` — score the rewrite and require it to hold or beat
the baseline per case before accepting.

## What this skill never does

- Never lets the skill under test judge its own output — judging is always the
  separate `skill-judge` agent.
- Never dispatches case-runners/judges before the mechanical precheck passes.
- Never reports a bare "looks good" — the verdict is the rubric scores and the
  threshold arithmetic.
