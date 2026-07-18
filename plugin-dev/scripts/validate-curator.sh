#!/usr/bin/env bash
# validate-curator.sh <skills-root> [--json]
# Validates the curator's persisted runtime artifacts (NOT plugin repo files —
# that is why the orchestrator validate-plugin.sh does not run this; the
# skill-curator skill invokes it at runtime before acting):
#   - <root>/.curator-pins  : `version:` header + one kebab slug per line
#   - <root>/.archive/      : each archived dir carries a SKILL.md; the
#                             snapshots/ dir holds only *.tar.gz
# Emits the shared findings contract. Default root: ~/.claude/skills.
set -eu
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$DIR/lib/findings.sh"
have_jq

JSON=0; ARGS=()
for a in "$@"; do case "$a" in --json) JSON=1 ;; *) ARGS+=("$a") ;; esac; done
[ "$JSON" = 1 ] && export FINDINGS_JSON=1
ROOT="${ARGS[0]:-$HOME/.claude/skills}"

PINS="$ROOT/.curator-pins"
if [ -f "$PINS" ]; then
  first=$(grep -vE '^\s*(#|$)' "$PINS" | head -1 || true)
  if ! printf '%s' "$first" | grep -qE '^version:[[:space:]]*[0-9]+$'; then
    add_finding error curator-pins-no-version curator "$PINS" 1 \
      "pins file must open with a 'version: <n>' header (first non-comment line)"
  fi
  # Slug lines: everything that is not the version header, a comment, or blank.
  ln=0
  while IFS= read -r line; do
    ln=$((ln+1))
    case "$line" in ''|\#*|version:*) continue ;; esac
    stripped=$(printf '%s' "$line" | tr -d '[:space:]')
    [ -z "$stripped" ] && continue
    printf '%s' "$stripped" | grep -qE '^[a-z0-9][a-z0-9-]*$' \
      || add_finding warn curator-pins-bad-slug curator "$PINS" "$ln" \
           "pin entry '$stripped' is not a valid kebab-case skill slug"
  done < "$PINS"
fi

ARCHIVE="$ROOT/.archive"
if [ -d "$ARCHIVE" ]; then
  # Each archived skill dir (not snapshots) should carry a SKILL.md.
  while IFS= read -r d; do
    [ -f "$d/SKILL.md" ] || add_finding warn curator-archive-orphan curator "$d" 0 \
      "archived directory has no SKILL.md — not a recoverable skill archive"
  done < <(find "$ARCHIVE" -mindepth 1 -maxdepth 1 -type d -not -name snapshots | sort)
  # Snapshots dir holds only tarballs.
  if [ -d "$ARCHIVE/snapshots" ]; then
    while IFS= read -r f; do
      case "$f" in *.tar.gz) : ;; *) add_finding info curator-snapshot-foreign curator "$f" 0 \
        "non-tarball file in snapshots/ — snapshots are *.tar.gz" ;; esac
    done < <(find "$ARCHIVE/snapshots" -mindepth 1 -maxdepth 1 -type f | sort)
  fi
fi

render_findings "validate-curator.sh" "$ROOT"; exit $?
