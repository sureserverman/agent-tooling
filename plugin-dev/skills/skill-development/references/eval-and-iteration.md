# Iteration & evaluation

Test-driven authoring, description tuning, and improvement principles for
skills. Distilled from Anthropic's `skill-creator` reference plugin and from
session-tested practice.

## TOC
- [1. Capturing intent](#1-capturing-intent)
- [2. Test-driven iteration loop](#2-test-driven-iteration-loop)
- [3. Improvement principles](#3-improvement-principles)
- [4. Description tuning](#4-description-tuning)
- [5. How skill triggering actually works](#5-how-skill-triggering-actually-works)

---

## 1. Capturing intent

Before drafting, answer four questions — extract from prior conversation
where possible, ask only the gaps:

1. What should this skill enable Claude to do?
2. When should this skill fire? (Concrete user phrases / contexts.)
3. What is the expected output format?
4. Are outputs objectively verifiable, so automated tests will help?

Skills with verifiable outputs (file transforms, data extraction, code
generation, fixed workflows) benefit from automated tests. Subjective skills
(writing style, design taste) are better evaluated qualitatively — don't
force assertions where human judgment is the right tool.

---

## 2. Test-driven iteration loop

For skills with verifiable outputs:

1. **Draft 2–3 realistic test prompts.** Not abstract — the kind of thing a
   real user would type. Save to `evals/evals.json` as
   `{"id", "prompt", "expected_output", "files"}`.
2. **Run with-skill and baseline in parallel.** For each prompt, dispatch two
   subagents in the same turn: one with the skill loaded, one without (for a
   new skill) or against a snapshot of the prior version (for an edit). Save
   outputs under `<skill-name>-workspace/iteration-N/eval-<id>/{with_skill,without_skill}/`.
3. **Draft assertions while runs execute.** Don't idle. Each assertion is one
   objectively-verifiable claim with a descriptive name. Skip assertions on
   subjective skills.
4. **Grade and aggregate.** Spawn a grader subagent emitting `grading.json`
   per run with `text / passed / evidence` fields. Aggregate into
   `benchmark.json` with pass rate plus mean ± stddev for time and tokens,
   and the with-skill vs baseline delta.
5. **Review with the user.** Show qualitative outputs alongside the
   benchmark. The human catches what assertions miss.
6. **Improve and repeat.** Apply changes, rerun into `iteration-N+1/`,
   compare to the previous iteration. Stop when the user is happy, feedback
   is empty, or progress plateaus.

SKILL.md text edits are picked up live (v2.1.x change detection) — no
restart between iterations. Edits to other plugin components (hooks,
agents, scripts) still need `/reload-plugins`.

The exact viewer/aggregation tooling lives upstream in Anthropic's
`skill-creator` plugin (clone the marketplace if the full automated harness
is wanted). The methodology above is reproducible without it.

---

## 3. Improvement principles

When iterating on a skill based on test-run feedback:

- **Generalize from feedback; don't overfit.** A skill that passes three test
  cases but fails on the millionth real prompt is worthless. If feedback
  points at a failure, find the principle behind it before patching the
  symptom.
- **Keep the prompt lean.** Read the *transcripts*, not just the outputs —
  if the skill is making the model waste time on dead ends, the corresponding
  instruction is dead weight. Cut, don't pile on.
- **Explain the why; don't shout MUSTs.** Models with theory of mind can
  reason about purpose. Heavy-handed rigid `ALWAYS` / `NEVER` rules are a
  yellow flag — reframe as the constraint they encode plus the reason for it.
- **Bundle repeated work into `scripts/`.** If three test runs all
  independently wrote nearly the same helper, that helper belongs in the
  skill. Write it once, ship it, point the body at it.

---

## 4. Description tuning

The description is the trigger spec — see `description-style.md` for the
style rules. To tune triggering quality empirically:

### 4.1 Eval query design

Generate ~20 queries split should-trigger / should-not-trigger:

- **Concrete and realistic.** Include backstory: file paths, column names,
  vendor names, casual speech, typos. Mix lengths and registers.
- **Should-trigger (8–10):** different phrasings of the same intent — formal
  and casual; cases where the user doesn't name the skill explicitly but
  clearly needs it; competition-with-another-skill cases this one should win.
- **Should-not-trigger (8–10):** *near-misses*. Queries that share keywords
  or concepts with the skill but need something else. Adjacent domains,
  ambiguous keyword overlap, contexts where a different tool is the right
  answer.

The trap: making should-not-trigger queries trivially irrelevant. "Write a
fibonacci function" as a negative for a PDF skill tests nothing. Negatives
must be genuinely tricky, or the eval set produces a description that just
keyword-matches.

### 4.2 Bad vs good query

Bad: `"Format this data"` — abstract, untestable.

Good: *"ok so my boss just sent me this xlsx file (its in my downloads,
called something like 'Q4 sales final FINAL v2.xlsx') and she wants me to
add a column that shows the profit margin as a percentage. The revenue is
in column C and costs are in column D i think"*

Concrete enough that a real user might type it, and substantive enough that
Claude will actually consult skills (see §5).

### 4.3 Anti-overfit split

Split the eval set 60/40 train/test. Tune the description against the
training half, score candidates against the held-out test half, and pick
the description that wins on test — not train. Iterating purely against
train overfits to the eval set itself.

---

## 5. How skill triggering actually works

Skills appear in Claude's `available_skills` list as name + description
(+ `when_to_use`) only. Claude consults a skill when (a) the description
matches the user request *and* (b) the task is complex enough that the
skill would help.

Budget mechanics (v2.1.170) that shape triggering:

- The whole listing shares ~1% of the context window
  (`skillListingBudgetFraction`); each entry is truncated at 1,536 chars.
  Tail-loaded trigger phrases are invisible — front-load them.
- On compaction, loaded skill content is retained as the first 5,000
  tokens per skill within a 25,000-token shared budget. Long-session
  evals can therefore behave differently from fresh-session evals.
- `disable-model-invocation: true` removes a skill from the listing
  entirely — such skills can never auto-trigger and are pointless to
  trigger-tune.
- `paths:` glob gating means a perfectly tuned description still won't
  fire when no matching files are in play; include matching files in
  eval fixtures.

The corollary — **simple, one-step queries don't trigger skills regardless
of description quality**. "Read this PDF" won't reliably trigger a PDF
skill because Claude can read PDFs directly. Multi-step or specialized
requests trigger reliably.

Implication for eval queries: trivial prompts produce non-discriminating
results. Both with-skill and baseline runs handle them. Use substantive
prompts — where Claude visibly benefits from consulting a skill — or the
eval signal is noise.
