#!/usr/bin/env bash
# validate-skill.sh <path-to-SKILL.md | skill-dir> [--json]
# Deterministic checks for a skill: frontmatter, name↔dir, description bounds,
# SKILL.md length, reference nesting depth, POV/leak candidates.
set -eu
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$DIR/lib/findings.sh"
have_jq

JSON=0; ARGS=()
for a in "$@"; do case "$a" in --json) JSON=1 ;; *) ARGS+=("$a") ;; esac; done
[ "$JSON" = 1 ] && export FINDINGS_JSON=1
TARGET="${ARGS[0]:-}"
[ -n "$TARGET" ] || { echo "usage: $0 <SKILL.md|skill-dir> [--json]" >&2; exit 2; }

if [ -d "$TARGET" ]; then SKILL="$TARGET/SKILL.md"; SDIR="$TARGET"; else SKILL="$TARGET"; SDIR="$(dirname "$TARGET")"; fi
REL="$SKILL"

if [ ! -f "$SKILL" ]; then
  add_finding error skill-missing skill "$REL" 0 "no SKILL.md found at $SKILL"
  render_findings "validate-skill.sh" "$TARGET"; exit $?
fi

if ! has_closing_fence "$SKILL"; then
  add_finding error skill-no-frontmatter skill "$REL" 1 "SKILL.md must open and close a YAML frontmatter block (---)"
  render_findings "validate-skill.sh" "$TARGET"; exit $?
fi

NAME=$(frontmatter_field "$SKILL" name)
DESC=$(frontmatter_field "$SKILL" description)
DESC_LINE=$(grep -n '^description:' "$SKILL" | head -1 | cut -d: -f1); DESC_LINE=${DESC_LINE:-0}

[ -n "$NAME" ] || add_finding error skill-no-name skill "$REL" 0 "frontmatter missing required field: name"
[ -n "$DESC" ] || add_finding error skill-no-description skill "$REL" 0 "frontmatter missing required field: description"

if [ -n "$NAME" ]; then
  DIRBASE=$(basename "$SDIR")
  [ "$NAME" = "$DIRBASE" ] \
    || add_finding error skill-name-mismatch skill "$REL" 0 "name '$NAME' must match the skill directory '$DIRBASE'"
fi

if [ -n "$DESC" ]; then
  len=${#DESC}
  if [ "$len" -gt 1024 ]; then
    add_finding error skill-desc-too-long skill "$REL" "$DESC_LINE" "description is $len chars (hard cap 1024)"
  elif [ "$len" -gt 800 ]; then
    add_finding warn skill-desc-long skill "$REL" "$DESC_LINE" "description is $len chars (>800 risks truncation when many skills load)"
  fi
  check_description "$REL" "$DESC_LINE" skill "$DESC"
fi

lines=$(wc -l < "$SKILL" | tr -d ' ')
if [ "$lines" -gt 500 ]; then
  add_finding warn skill-too-long skill "$REL" 0 "SKILL.md is $lines lines (>500; push depth into references/)"
elif [ "$lines" -gt 300 ] && [ ! -d "$SDIR/references" ]; then
  add_finding info skill-no-references skill "$REL" 0 "SKILL.md is $lines lines with no references/ — consider progressive disclosure"
fi

# reference nesting: references/ must be exactly one level deep
if [ -d "$SDIR/references" ]; then
  while IFS= read -r deep; do
    [ -n "$deep" ] || continue
    add_finding warn skill-ref-too-deep skill "${deep#"$SDIR"/}" 0 "reference file nested >1 level under references/ (keep references one level deep)"
  done < <(find "$SDIR/references" -mindepth 2 -type f 2>/dev/null)
fi

render_findings "validate-skill.sh" "$TARGET"; exit $?
