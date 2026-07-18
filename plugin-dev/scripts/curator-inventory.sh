#!/usr/bin/env bash
# curator-inventory.sh <root>... [--json]
# Read-only enumeration of every SKILL.md under one or more skill roots.
# Emits one record per skill: path, origin (personal|plugin), bytes, mtime
# (epoch seconds), name, description.
#
# Origin is decided structurally, not by which root was passed: a skill is
# `plugin` iff any ancestor directory (up to the scan root) carries a
# `.claude-plugin/plugin.json` or `.claude-plugin/marketplace.json` — i.e. it is
# shipped by a plugin/marketplace. Everything else is `personal` (a hand-written
# skill under ~/.claude/skills). This lets the curator scan the personal dir and
# marketplace repos in one pass and still classify each skill correctly.
#
# Pure read-only. --json prints {"skills":[...]}; without it, a human table.
set -eu
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$DIR/lib/findings.sh"   # frontmatter_field, have_jq
have_jq

JSON=0; ROOTS=()
for a in "$@"; do
  case "$a" in
    --json) JSON=1 ;;
    *) ROOTS+=("$a") ;;
  esac
done
[ "${#ROOTS[@]}" -gt 0 ] || ROOTS=("$HOME/.claude/skills")

# origin_of <skill-dir> <scan-root> — echo "plugin" or "personal".
origin_of() {
  local d="$1" root="$2"
  d="$(cd "$d" && pwd)"
  root="$(cd "$root" && pwd)"
  while :; do
    if [ -f "$d/.claude-plugin/plugin.json" ] || [ -f "$d/.claude-plugin/marketplace.json" ]; then
      echo plugin; return
    fi
    [ "$d" = "$root" ] && break
    local parent; parent="$(dirname "$d")"
    [ "$parent" = "$d" ] && break
    d="$parent"
  done
  echo personal
}

RECORDS=()
for root in "${ROOTS[@]}"; do
  [ -d "$root" ] || continue
  while IFS= read -r skill; do
    sdir="$(dirname "$skill")"
    origin="$(origin_of "$sdir" "$root")"
    bytes="$(wc -c < "$skill" | tr -d ' ')"
    mtime="$(stat -c %Y "$skill" 2>/dev/null || stat -f %m "$skill" 2>/dev/null || echo 0)"
    name="$(frontmatter_field "$skill" name)"
    desc="$(frontmatter_field "$skill" description)"
    RECORDS+=("$(jq -nc \
      --arg path "$skill" --arg origin "$origin" \
      --argjson bytes "${bytes:-0}" --argjson mtime "${mtime:-0}" \
      --arg name "$name" --arg description "$desc" \
      '{path:$path,origin:$origin,bytes:$bytes,mtime:$mtime,name:$name,description:$description}')")
  done < <(find "$root" -mindepth 2 -maxdepth 6 -name SKILL.md -type f -not -path '*/.archive/*' | sort)
done

if [ "${#RECORDS[@]}" -gt 0 ]; then
  SKILLS_JSON=$(printf '%s\n' "${RECORDS[@]}" | jq -s '.')
else
  SKILLS_JSON='[]'
fi

if [ "$JSON" = 1 ]; then
  jq -n --argjson skills "$SKILLS_JSON" '{skills:$skills}'
else
  printf '%s' "$SKILLS_JSON" | jq -r '.[] | "\(.origin)\t\(.bytes)B\t\(.name)\t\(.path)"' \
    | column -t -s $'\t' 2>/dev/null || printf '%s' "$SKILLS_JSON" | jq -r '.[] | "\(.origin) \(.name) \(.path)"'
fi
