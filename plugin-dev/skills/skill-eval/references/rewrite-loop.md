# Rewrite → eval → accept

When a skill is rewritten — by `stingy-agents:skill-rewriter` or by hand — the
rewrite must be shown not to regress the skill before it is accepted. This is the
GEPA discipline minus the evolutionary search: we don't auto-generate variants,
but any candidate is gated against a baseline.

## Protocol

1. **Baseline.** Before rewriting, run the eval set against the current skill and
   record the judge scores as `baseline.json`
   (`[{case_id, weighted_total}, …]` — the same array Step 4 of the skill
   assembles).
2. **Rewrite.** Apply the change (rewriter agent or manual edit).
3. **Re-precheck.** Run `skill-eval-gate.sh precheck` on the rewritten skill —
   pass `--baseline-desc <file>` with the pre-rewrite description so a **purpose
   drift** (description changed) is surfaced for the user, not slipped through.
4. **Re-eval.** Run the eval set against the rewrite; record `candidate.json`.
5. **Compare.**

   ```bash
   bash "${CLAUDE_PLUGIN_ROOT}/scripts/skill-eval-gate.sh" compare baseline.json candidate.json
   ```

   It returns `{accepted, regressions:[{case_id, baseline, candidate}]}`. A
   candidate is **accepted only if it holds or beats the baseline on every
   case** — a single per-case regression rejects it (exit non-zero), naming the
   regressed cases.

6. **Land it as a reviewable diff.** An accepted rewrite is committed as a normal
   git change — a diff a human can read — never auto-committed silently. (Hermes
   ships GEPA winners as PRs; here the working-tree diff is the review surface.)

## Why per-case, not just the aggregate

A rewrite can lift the average while quietly breaking one important case. Gating
per case (not on the mean) means an improvement in one area can never pay for a
regression in another — the skill must be at least as good everywhere it was
measured.
