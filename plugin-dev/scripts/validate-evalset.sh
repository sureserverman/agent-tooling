#!/usr/bin/env bash
# validate-evalset.sh <cases.yaml> [--draft] [--json]
# Validates a skill eval set against the schema (see
# skills/skill-eval/references/evalset-format.md). YAML is converted to JSON by a
# thin python3+pyyaml adapter; all validation logic runs in jq on the shared
# findings contract. In --draft mode, rubric stubs (a case whose rubric is a
# `TODO` placeholder produced by evalset-mine.sh) are allowed.
#
# Emits the shared findings contract. Standalone (like validate-curator.sh): the
# skill-eval skill invokes it; it is not wired into validate-plugin.sh, which
# validates plugin repo files rather than authored eval sets.
set -eu
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$DIR/lib/findings.sh"
have_jq

JSON=0; DRAFT=0; ARGS=()
for a in "$@"; do case "$a" in
  --json) JSON=1 ;; --draft) DRAFT=1 ;; *) ARGS+=("$a") ;;
esac; done
[ "$JSON" = 1 ] && export FINDINGS_JSON=1
TARGET="${ARGS[0]:-}"
[ -n "$TARGET" ] || { echo "usage: $0 <cases.yaml> [--draft] [--json]" >&2; exit 2; }

if ! command -v python3 >/dev/null 2>&1 || ! python3 -c 'import yaml' 2>/dev/null; then
  echo "error: validate-evalset.sh needs python3 with pyyaml (pip install pyyaml)" >&2; exit 3
fi
if [ ! -f "$TARGET" ]; then
  add_finding error evalset-missing evalset "$TARGET" 0 "no eval set at $TARGET"
  render_findings "validate-evalset.sh" "$TARGET"; exit $?
fi

# YAML -> JSON (null on parse error so jq can flag it rather than crashing).
DOC=$(python3 -c 'import sys,yaml,json
try: print(json.dumps(yaml.safe_load(open(sys.argv[1]))))
except Exception as e: sys.stderr.write(str(e)); print("null")' "$TARGET" 2>/dev/null || echo null)

if [ "$DOC" = null ] || ! printf '%s' "$DOC" | jq -e 'type=="object"' >/dev/null 2>&1; then
  add_finding error evalset-unparseable evalset "$TARGET" 0 "not valid YAML mapping (could not parse to an object)"
  render_findings "validate-evalset.sh" "$TARGET"; exit $?
fi

field() { printf '%s' "$DOC" | jq -r "$1" 2>/dev/null; }

# version
[ "$(field '.version')" = "1" ] || add_finding error evalset-no-version evalset "$TARGET" 0 \
  "missing or unsupported 'version' (expected 1)"
# skill
[ -n "$(field '.skill // empty')" ] || add_finding error evalset-no-skill evalset "$TARGET" 0 \
  "missing 'skill' (the skill under evaluation)"
# thresholds
printf '%s' "$DOC" | jq -e '.thresholds and (.thresholds.min_case_score|type=="number") and (.thresholds.pass_fraction|type=="number")' >/dev/null 2>&1 \
  || add_finding error evalset-bad-thresholds evalset "$TARGET" 0 \
       "'thresholds' must set numeric min_case_score and pass_fraction"
# cases present
NCASES=$(printf '%s' "$DOC" | jq '(.cases // [])|length')
[ "$NCASES" -gt 0 ] || add_finding error evalset-no-cases evalset "$TARGET" 0 "no cases defined"

# per-case checks
i=0
while [ "$i" -lt "$NCASES" ]; do
  c=$(printf '%s' "$DOC" | jq ".cases[$i]")
  cid=$(printf '%s' "$c" | jq -r '.id // "<no-id>"')
  [ -n "$(printf '%s' "$c" | jq -r '.id // empty')" ] || add_finding error evalset-case-no-id evalset "$TARGET" 0 "case #$((i+1)) has no id"
  src=$(printf '%s' "$c" | jq -r '.source // empty')
  case "$src" in
    synthetic|session|golden) : ;;
    *) add_finding error evalset-bad-source evalset "$TARGET" 0 "case '$cid' has invalid source '$src' (want synthetic|session|golden)" ;;
  esac
  [ -n "$(printf '%s' "$c" | jq -r '.prompt // empty')" ] || add_finding error evalset-case-no-prompt evalset "$TARGET" 0 "case '$cid' has no prompt"
  # rubric: required unless --draft and it's a TODO stub
  hasrubric=$(printf '%s' "$c" | jq -e '(.rubric|type=="array") and (.rubric|length>0) and all(.rubric[]; .criterion and (.weight|type=="number"))' >/dev/null 2>&1 && echo 1 || echo 0)
  if [ "$hasrubric" = 0 ]; then
    isstub=$(printf '%s' "$c" | jq -e '.rubric=="TODO" or (.rubric|type=="null")' >/dev/null 2>&1 && echo 1 || echo 0)
    if [ "$DRAFT" = 1 ] && [ "$isstub" = 1 ]; then
      :  # draft stub allowed
    else
      add_finding error evalset-case-bad-rubric evalset "$TARGET" 0 "case '$cid' needs a rubric: a non-empty list of {criterion, weight}"
    fi
  fi
  i=$((i+1))
done

render_findings "validate-evalset.sh" "$TARGET"; exit $?
