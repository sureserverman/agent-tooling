#!/usr/bin/env bash
# curator-usage.sh [--sessions <dir>] [--json] <skill-name>...
# Read-only extraction of skill last-triggered timestamps from Claude Code
# session JSONL history. For each requested skill name, reports the most recent
# time it was invoked via the Skill tool, plus an invocation count.
#
# Namespacing: a Skill invocation records the *invocable* name, which may be
# namespaced ("planning:foo") or bare ("foo"). We match on the bare component
# (everything after the last ':'), which is the skill's frontmatter `name`.
#
# The critical distinction the curator relies on:
#   - a skill seen in history        -> {last:<iso>, count:N}
#   - a skill NEVER seen, with history present -> state "no-evidence"
#     (absence is weak: Claude Code prunes sessions past cleanupPeriodDays, so
#      "not in history" is NOT "unused" — the state machine falls back to mtime)
# Top-level `history_present` is false when no session files were scanned at all.
set -eu
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$DIR/lib/findings.sh"
have_jq

SESSDIR="$HOME/.claude/projects"
JSON=0; NAMES=()
while [ $# -gt 0 ]; do
  case "$1" in
    --sessions) SESSDIR="$2"; shift 2 ;;
    --json) JSON=1; shift ;;
    *) NAMES+=("$1"); shift ;;
  esac
done

# Aggregate skill -> "max_iso_ts count" across every session file.
# ISO-8601 timestamps sort chronologically as plain strings, so max == latest.
AGG=$(
  find "$SESSDIR" -name '*.jsonl' -type f 2>/dev/null -print0 \
    | while IFS= read -r -d '' f; do
        jq -rc 'select(.type=="assistant")
                | .timestamp as $t
                | (.message.content // [])[]?
                | select(type=="object" and .type=="tool_use" and .name=="Skill")
                | [$t, (.input.skill // "")] | @tsv' "$f" 2>/dev/null
      done \
    | awk -F'\t' '
        {
          skill=$2; sub(/.*:/,"",skill)          # bare component
          if (skill=="") next
          cnt[skill]++
          if ($1 > last[skill]) last[skill]=$1
        }
        END { for (s in cnt) printf "%s\t%s\t%d\n", s, last[s], cnt[s] }'
)

# Was there any history to scan at all?
HIST_COUNT=$(find "$SESSDIR" -name '*.jsonl' -type f 2>/dev/null | head -1 | wc -l | tr -d ' ')
HISTORY_PRESENT=$([ "$HIST_COUNT" -gt 0 ] && echo true || echo false)

lookup() { awk -F'\t' -v s="$1" '$1==s {print $2"\t"$3; found=1} END{if(!found)print "\t"}' <<<"$AGG"; }

RECORDS=()
for name in "${NAMES[@]}"; do
  IFS=$'\t' read -r ts cnt < <(lookup "$name")
  if [ -n "$ts" ]; then
    RECORDS+=("$(jq -nc --arg skill "$name" --arg last "$ts" --argjson count "${cnt:-0}" \
      '{skill:$skill,last:$last,count:$count}')")
  else
    RECORDS+=("$(jq -nc --arg skill "$name" \
      '{skill:$skill,last:null,count:0,state:"no-evidence"}')")
  fi
done

if [ "${#RECORDS[@]}" -gt 0 ]; then
  USAGE_JSON=$(printf '%s\n' "${RECORDS[@]}" | jq -s '.')
else
  USAGE_JSON='[]'
fi

if [ "$JSON" = 1 ]; then
  jq -n --argjson usage "$USAGE_JSON" --argjson hp "$HISTORY_PRESENT" \
    '{history_present:$hp,usage:$usage}'
else
  echo "history_present: $HISTORY_PRESENT"
  printf '%s' "$USAGE_JSON" | jq -r '.[] | "\(.skill)\t\(.last // .state)\t\(.count)"'
fi
