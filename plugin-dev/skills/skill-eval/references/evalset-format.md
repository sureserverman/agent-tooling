# Eval-set format (`cases.yaml`)

A skill's eval set lives beside it at `skills/<name>/evals/cases.yaml`. It is a
schema-versioned, human-authorable artifact. `validate-evalset.sh` enforces every
field documented here (YAML → JSON via python3+pyyaml, validated in jq).

```yaml
version: 1                      # required, must be 1
skill: skill-development        # required — the skill under evaluation
thresholds:                     # required
  min_case_score: 3.0           # required, number — min weighted 0–5 score per case
  pass_fraction: 1.0            # required, number — fraction of cases that must pass
                                #   (GEPA default 1.0 = every case must meet min)
cases:                          # required, non-empty
  - id: authors-a-valid-skill   # required, unique-ish label
    source: synthetic           # required — one of: synthetic | session | golden
    prompt: |                   # required — the situation handed to the case-runner
      Multi-line description of what the runner is asked to do, and what a good
      response looks like.
    rubric:                     # required (unless a --draft stub) — non-empty list
      - criterion: frontmatter valid (name matches dir, description present)
        weight: 2               # number; the judge scores each criterion 0–5
      - criterion: description states when-to-use, not the workflow steps
        weight: 1
    session_ref: null           # optional — provenance for source: session
```

## Field rules (all validator-enforced)

| Field | Rule | Finding if violated |
|---|---|---|
| `version` | equals `1` | `evalset-no-version` |
| `skill` | non-empty string | `evalset-no-skill` |
| `thresholds.min_case_score` | number | `evalset-bad-thresholds` |
| `thresholds.pass_fraction` | number | `evalset-bad-thresholds` |
| `cases` | non-empty list | `evalset-no-cases` |
| `cases[].id` | present | `evalset-case-no-id` |
| `cases[].source` | `synthetic`\|`session`\|`golden` | `evalset-bad-source` |
| `cases[].prompt` | non-empty | `evalset-case-no-prompt` |
| `cases[].rubric` | non-empty list of `{criterion, weight:number}` | `evalset-case-bad-rubric` |

## Sources

- **synthetic** — authored by hand (or by the skill-eval author) to probe a
  specific behavior.
- **session** — drafted from real session history by `evalset-mine.sh`, which
  finds sessions where the skill actually fired and lifts the triggering context
  into a case (with `session_ref` provenance and a `TODO` rubric stub for the
  author to finish).
- **golden** — hand-picked exemplars the skill must always get right.

## Draft mode

`validate-evalset.sh --draft` accepts a case whose `rubric` is the literal `TODO`
(or null) — the stub `evalset-mine.sh` emits. A non-draft validation requires
every rubric to be a real list, so an eval set can't ship with unfinished
rubrics.

## Scoring (consumed by skill-eval / skill-judge)

The judge scores each `criterion` 0–5 with evidence; a case's weighted score is
`Σ(score·weight) / Σ(weight)`. A case passes when that ≥ `min_case_score`; the
eval set passes when the passing fraction ≥ `pass_fraction`.
