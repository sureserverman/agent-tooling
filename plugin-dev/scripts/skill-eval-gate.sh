#!/usr/bin/env bash
# skill-eval-gate.sh <precheck|verdict> ... — the deterministic half of skill-eval.
# The LLM half (running cases, judging) lives in the skill-eval skill + skill-judge
# agent; the mechanical gates and threshold arithmetic live here so they are cheap,
# reproducible, and run BEFORE any API spend.
#
#   precheck <skill-dir> <cases.yaml> [--max-bytes N] [--baseline-desc <file>] [--json]
#       Hard mechanical gates. Exits non-zero (findings contract) if any fails —
#       the skill must stop here and never dispatch case-runners/judges.
#       - SKILL.md size <= 15 KB (15360 bytes; GEPA's 15 KB ceiling)
#       - eval set passes validate-evalset.sh (non-draft)
#       - description present; if --baseline-desc given, flag drift for review
#
#   verdict <cases.yaml> <scores.json>
#       Applies thresholds to judge scores. scores.json = [{case_id, weighted_total}].
#       Prints {verdict:PASS|FAIL, pass_fraction_actual, cases:[…], failed:[ids]}.
set -eu
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$DIR/lib/findings.sh"
have_jq
CMD="${1:-}"; shift || true

yaml2json() { python3 -c 'import sys,yaml,json; print(json.dumps(yaml.safe_load(open(sys.argv[1]))))' "$1"; }

case "$CMD" in
  precheck)
    JSON=0; MAXB=15360; BASELINE=""; ARGS=()
    while [ $# -gt 0 ]; do case "$1" in
      --json) JSON=1; shift ;;
      --max-bytes) MAXB="$2"; shift 2 ;;
      --baseline-desc) BASELINE="$2"; shift 2 ;;
      *) ARGS+=("$1"); shift ;;
    esac; done
    [ "$JSON" = 1 ] && export FINDINGS_JSON=1
    SDIR="${ARGS[0]:-}"; CASES="${ARGS[1]:-}"
    [ -n "$SDIR" ] && [ -n "$CASES" ] || { echo "usage: $0 precheck <skill-dir> <cases.yaml>" >&2; exit 2; }
    SKILL="$SDIR/SKILL.md"

    if [ ! -f "$SKILL" ]; then
      add_finding error evalgate-no-skill evalgate "$SKILL" 0 "no SKILL.md at $SDIR"
    else
      bytes=$(wc -c < "$SKILL" | tr -d ' ')
      if [ "$bytes" -gt "$MAXB" ]; then
        add_finding error evalgate-skill-too-big evalgate "$SKILL" 0 \
          "SKILL.md is $bytes bytes (> $MAXB / 15 KB ceiling) — trim before evaluating"
      fi
      desc=$(frontmatter_field "$SKILL" description)
      [ -n "$desc" ] || add_finding error evalgate-no-desc evalgate "$SKILL" 0 "SKILL.md frontmatter has no description"
      if [ -n "$BASELINE" ] && [ -f "$BASELINE" ]; then
        base=$(cat "$BASELINE")
        [ "$desc" = "$base" ] || add_finding warn evalgate-desc-drift evalgate "$SKILL" 0 \
          "description differs from baseline — confirm the skill's purpose hasn't drifted before accepting a rewrite"
      fi
    fi

    # Eval set must be valid (non-draft: real rubrics required before scoring).
    evout=$(FINDINGS_JSON=1 bash "$DIR/validate-evalset.sh" "$CASES" --json 2>/dev/null || true)
    everrs=$(printf '%s' "$evout" | jq '[.findings[]?|select(.severity=="error")]|length' 2>/dev/null || echo 1)
    if [ "${everrs:-1}" -gt 0 ]; then
      add_finding error evalgate-bad-evalset evalgate "$CASES" 0 "eval set failed validate-evalset.sh ($everrs error(s)) — fix before evaluating"
    fi

    render_findings "skill-eval-gate.sh precheck" "$SDIR"; exit $?
    ;;

  verdict)
    CASES="${1:-}"; SCORES="${2:-}"
    [ -n "$CASES" ] && [ -n "$SCORES" ] || { echo "usage: $0 verdict <cases.yaml> <scores.json>" >&2; exit 2; }
    CJSON=$(yaml2json "$CASES")
    MIN=$(printf '%s' "$CJSON" | jq -r '.thresholds.min_case_score')
    PF=$(printf '%s' "$CJSON" | jq -r '.thresholds.pass_fraction')
    SC=$(cat "$SCORES")

    # Join each case id to its judged weighted_total; pass iff >= MIN.
    RESULT=$(printf '%s' "$CJSON" | jq \
      --argjson scores "$SC" --argjson min "$MIN" --argjson pf "$PF" '
      [ .cases[] | .id as $id
        # array-then-first so a case with NO matching score binds null (a fail),
        # never dropped from the set — a missing/crashed judge must FAIL, not
        # silently vanish from numerator AND denominator. first also collapses
        # duplicate score rows so they cannot inflate the denominator.
        | ( ([$scores[] | select(.case_id==$id) | .weighted_total] | first) // null ) as $wt
        | {id:$id, weighted_total:$wt,
           min:$min, pass:(($wt // -1) >= $min)} ] as $cases
      | ($cases | map(select(.pass)) | length) as $npass
      | ($cases | length) as $n
      | {verdict: (if $n>0 and ($npass/$n) >= $pf then "PASS" else "FAIL" end),
         pass_fraction_required:$pf,
         pass_fraction_actual: (if $n>0 then ($npass/$n) else 0 end),
         cases:$cases,
         failed: ($cases | map(select(.pass|not) | .id))}')
    echo "$RESULT"
    # exit non-zero on FAIL so callers can branch
    [ "$(printf '%s' "$RESULT" | jq -r '.verdict')" = PASS ]
    ;;

  compare)
    # compare <baseline-scores.json> <candidate-scores.json>
    # Accept a rewrite iff its weighted_total holds or beats the baseline for
    # EVERY case the baseline scored. A single per-case regression rejects it.
    BASE="${1:-}"; CAND="${2:-}"
    [ -n "$BASE" ] && [ -n "$CAND" ] || { echo "usage: $0 compare <baseline.json> <candidate.json>" >&2; exit 2; }
    B=$(cat "$BASE"); C=$(cat "$CAND")
    RESULT=$(jq -n --argjson base "$B" --argjson cand "$C" '
      [ $base[] | .case_id as $id | {
          case_id:$id,
          baseline:.weighted_total,
          candidate: (($cand[] | select(.case_id==$id) | .weighted_total) // null)
        } | .regressed = ((.candidate // -1) < .baseline) ] as $rows
      | {accepted: ($rows | all(.regressed|not)),
         regressions: ($rows | map(select(.regressed)))}')
    echo "$RESULT"
    [ "$(printf '%s' "$RESULT" | jq -r '.accepted')" = true ]
    ;;

  *)
    echo "usage: $0 <precheck|verdict|compare> ..." >&2; exit 2 ;;
esac
