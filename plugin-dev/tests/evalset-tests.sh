#!/usr/bin/env bash
# evalset-tests.sh — re-runnable coverage for the skill-eval harness scripts:
# validate-evalset.sh and evalset-mine.sh, against tests/fixtures/evalset/.
#   bash plugin-dev/tests/evalset-tests.sh
set -eu
TDIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
S="$TDIR/../scripts"; FX="$TDIR/fixtures/evalset"
PASS=0; FAIL=0
ok()  { PASS=$((PASS+1)); printf '  ok   %s\n' "$1"; }
bad() { FAIL=$((FAIL+1)); printf '  FAIL %s\n' "$1"; }
check() { if printf '%s' "$3" | jq -e "$2" >/dev/null 2>&1; then ok "$1"; else bad "$1"; fi; }

echo "validate-evalset:"
G=$(bash "$S/validate-evalset.sh" "$FX/good.yaml" --json 2>/dev/null)
check "good.yaml -> zero findings" '.summary.errors==0 and (.findings|length==0)' "$G"
V=$(bash "$S/validate-evalset.sh" "$FX/bad-noversion.yaml" --json 2>/dev/null || true)
check "no version -> one version finding" '.summary.errors==1 and .findings[0].rule=="evalset-no-version"' "$V"
SR=$(bash "$S/validate-evalset.sh" "$FX/bad-source.yaml" --json 2>/dev/null || true)
check "bad source -> one source finding" '.summary.errors==1 and any(.findings[]; .rule=="evalset-bad-source")' "$SR"
NR=$(bash "$S/validate-evalset.sh" "$FX/bad-norubric.yaml" --json 2>/dev/null || true)
check "no rubric -> one rubric finding" '.summary.errors==1 and any(.findings[]; .rule=="evalset-case-bad-rubric")' "$NR"

echo "evalset-mine:"
bash "$S/evalset-mine.sh" alpha --sessions "$FX/mine-sessions" > /tmp/evalset-mined.yaml 2>/dev/null
MINED=$(python3 -c 'import yaml,json,sys; print(json.dumps(yaml.safe_load(open("/tmp/evalset-mined.yaml"))))')
check "mines session cases with source+ref+stub" 'all(.cases[]; .source=="session" and (.session_ref|length>0) and .rubric=="TODO")' "$MINED"
check "prompt carries user context" 'any(.cases[]; .prompt|test("scaffold a SKILL.md"))' "$MINED"
DV=$(bash "$S/validate-evalset.sh" /tmp/evalset-mined.yaml --draft --json 2>/dev/null)
check "mined draft validates under --draft" '.summary.errors==0' "$DV"
ND=$(bash "$S/validate-evalset.sh" /tmp/evalset-mined.yaml --json 2>/dev/null || true)
check "mined draft rejected without --draft" '.summary.errors>=1' "$ND"
if bash "$S/evalset-mine.sh" neverfired --sessions "$FX/mine-sessions" >/dev/null 2>&1; then bad "no-usage skill -> nonzero"; else ok "no-usage skill -> nonzero"; fi

echo "skill-eval-gate (precheck/verdict/compare):"
PC=$(bash "$S/skill-eval-gate.sh" precheck "$FX/skilldir-good" "$FX/skilldir-good/evals/cases.yaml" --json 2>/dev/null)
check "good skill precheck passes" '.summary.errors==0' "$PC"
BG=$(bash "$S/skill-eval-gate.sh" precheck "$FX/skilldir-big" "$FX/skilldir-good/evals/cases.yaml" --json 2>/dev/null || true)
check "16KB skill rejected pre-dispatch" 'any(.findings[]; .rule=="evalgate-skill-too-big")' "$BG"
VP=$(bash "$S/skill-eval-gate.sh" verdict "$FX/skilldir-good/evals/cases.yaml" "$FX/scores-pass.json" 2>/dev/null)
check "passing scores -> PASS" '.verdict=="PASS" and (.failed|length==0)' "$VP"
VF=$(bash "$S/skill-eval-gate.sh" verdict "$FX/skilldir-good/evals/cases.yaml" "$FX/scores-fail.json" 2>/dev/null || true)
check "sabotaged scores -> FAIL names case" '.verdict=="FAIL" and (.failed|index("catches-description-leak")!=null)' "$VF"
CR=$(bash "$S/skill-eval-gate.sh" compare "$FX/scores-baseline.json" "$FX/scores-regress.json" 2>/dev/null || true)
check "regressing rewrite rejected" '.accepted==false and (.regressions[0].case_id=="catches-description-leak")' "$CR"
CI=$(bash "$S/skill-eval-gate.sh" compare "$FX/scores-baseline.json" "$FX/scores-improve.json" 2>/dev/null)
check "improving rewrite accepted" '.accepted==true and (.regressions|length==0)' "$CI"

echo
echo "evalset-tests: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
