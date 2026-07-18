#!/usr/bin/env bash
# curator-scan.sh <root>... [--sessions <dir>] [--pins <file>] [--now <epoch>] [--json]
# The curator's read-only state machine. Merges curator-inventory.sh (what
# skills exist) with curator-usage.sh (when each was last triggered) into a
# lifecycle state per skill. Emits data only — never writes, never mutates.
#
# It does NOT fork the inventory/usage logic: it invokes both sibling scripts.
#
# Lifecycle (personal skills only):
#   fresh              age < 30d
#   stale              30d <= age < 90d
#   archive-candidate  age >= 90d
#   pinned             listed in the pins file — never archive-candidate,
#                      still patch-eligible (Hermes: pin exempts archival only)
# Plugin/marketplace-shipped skills are always `report-only`: the curator
# surfaces them but never touches git-managed skills.
#
# Age basis: the skill's last Skill-tool invocation if history has one
# (basis "usage"); otherwise the SKILL.md mtime (basis "mtime"), because
# "no-evidence" (see curator-usage.sh) must not be read as "unused" — session
# history is pruned past cleanupPeriodDays.
#
# --now <epoch> pins "today" so tests are deterministic; defaults to date +%s.
set -eu
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$DIR/lib/findings.sh"
have_jq

STALE_DAYS=30; ARCHIVE_DAYS=90
SESSDIR="$HOME/.claude/projects"
PINS="$HOME/.claude/skills/.curator-pins"
NOW=""; JSON=0; ROOTS=()
while [ $# -gt 0 ]; do
  case "$1" in
    --sessions) SESSDIR="$2"; shift 2 ;;
    --pins) PINS="$2"; shift 2 ;;
    --now) NOW="$2"; shift 2 ;;
    --json) JSON=1; shift ;;
    *) ROOTS+=("$1"); shift ;;
  esac
done
[ "${#ROOTS[@]}" -gt 0 ] || ROOTS=("$HOME/.claude/skills")
[ -n "$NOW" ] || NOW=$(date +%s)

# Pinned slugs (skip the `version:` header and blank/comment lines).
PINNED=""
if [ -f "$PINS" ]; then
  PINNED=$(grep -vE '^\s*(version:|#|$)' "$PINS" | tr -d ' ' || true)
fi
is_pinned() { printf '%s\n' "$PINNED" | grep -qxF "$1"; }

INV=$(bash "$DIR/curator-inventory.sh" "${ROOTS[@]}" --json)
NAMES=$(printf '%s' "$INV" | jq -r '.skills[].name' | sort -u)
[ -n "$NAMES" ] && USAGE=$(bash "$DIR/curator-usage.sh" --sessions "$SESSDIR" --json $NAMES) || USAGE='{"usage":[]}'

iso_to_epoch() { # strip millis, tolerate GNU/BSD date
  local t="${1%.*}"; [ "${t: -1}" = Z ] || t="${t}Z"
  date -u -d "$t" +%s 2>/dev/null || date -u -jf "%Y-%m-%dT%H:%M:%SZ" "$t" +%s 2>/dev/null || echo 0
}

RECORDS=()
while IFS= read -r rec; do
  name=$(jq -r '.name' <<<"$rec")
  origin=$(jq -r '.origin' <<<"$rec")
  path=$(jq -r '.path' <<<"$rec")
  mtime=$(jq -r '.mtime' <<<"$rec")
  last=$(printf '%s' "$USAGE" | jq -r --arg n "$name" '.usage[]|select(.skill==$n)|.last // empty' | head -1)
  if [ -n "$last" ] && [ "$last" != "null" ]; then
    eff=$(iso_to_epoch "$last"); basis="usage"
  else
    eff="$mtime"; basis="mtime"; last=null
  fi
  age_days=$(( (NOW - eff) / 86400 ))

  if [ "$origin" = plugin ]; then
    state="report-only"
  elif is_pinned "$name"; then
    state="pinned"
  elif [ "$age_days" -ge "$ARCHIVE_DAYS" ]; then
    state="archive-candidate"
  elif [ "$age_days" -ge "$STALE_DAYS" ]; then
    state="stale"
  else
    state="fresh"
  fi

  lastjson=$([ "$last" = null ] && echo null || jq -nc --arg l "$last" '$l')
  RECORDS+=("$(jq -nc --arg name "$name" --arg origin "$origin" --arg path "$path" \
    --arg state "$state" --argjson age_days "$age_days" --arg basis "$basis" --argjson last "$lastjson" \
    '{name:$name,origin:$origin,path:$path,state:$state,age_days:$age_days,basis:$basis,last:$last}')")
done < <(printf '%s' "$INV" | jq -c '.skills[]')

if [ "${#RECORDS[@]}" -gt 0 ]; then
  SKILLS=$(printf '%s\n' "${RECORDS[@]}" | jq -s '.')
else
  SKILLS='[]'
fi

if [ "$JSON" = 1 ]; then
  jq -n --argjson skills "$SKILLS" --argjson now "$NOW" '{now:$now,skills:$skills}'
else
  printf '%s' "$SKILLS" | jq -r '.[] | "\(.state)\t\(.origin)\t\(.age_days)d\t\(.basis)\t\(.name)"' \
    | sort | column -t -s $'\t' 2>/dev/null || printf '%s' "$SKILLS" | jq -r '.[] | "\(.state) \(.name)"'
fi
