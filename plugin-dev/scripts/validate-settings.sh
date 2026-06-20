#!/usr/bin/env bash
# validate-settings.sh <settings.local.md> [--json]
# Deterministic checks for a plugin settings file (.claude/<plugin>.local.md).
# Supersedes skills/plugin-settings/scripts/validate-settings.sh, which always
# exited 0. This one fails on real errors and emits the JSON contract.
set -eu
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$DIR/lib/findings.sh"
have_jq

JSON=0; ARGS=()
for a in "$@"; do case "$a" in --json) JSON=1 ;; *) ARGS+=("$a") ;; esac; done
[ "$JSON" = 1 ] && export FINDINGS_JSON=1
F="${ARGS[0]:-}"
[ -n "$F" ] || { echo "usage: $0 <settings.local.md> [--json]" >&2; exit 2; }
REL="$F"

if [ ! -f "$F" ]; then
  add_finding error settings-missing settings "$REL" 0 "settings file not found"
  render_findings "validate-settings.sh" "$F"; exit $?
fi
if [ ! -r "$F" ]; then
  add_finding error settings-unreadable settings "$REL" 0 "settings file is not readable"
  render_findings "validate-settings.sh" "$F"; exit $?
fi
if ! has_closing_fence "$F"; then
  add_finding error settings-no-frontmatter settings "$REL" 1 "settings must store config in a YAML frontmatter block (--- … ---)"
  render_findings "validate-settings.sh" "$F"; exit $?
fi

fm=$(extract_frontmatter "$F")
if [ -z "$(printf '%s' "$fm" | tr -d '[:space:]')" ]; then
  add_finding warn settings-empty settings "$REL" 0 "frontmatter is empty — no settings defined"
elif ! printf '%s\n' "$fm" | grep -Eq '^[A-Za-z0-9_-]+:'; then
  add_finding warn settings-no-keys settings "$REL" 0 "frontmatter has no key: value pairs"
fi

# common boolean fields must be true/false
while IFS= read -r line; do
  key=$(printf '%s' "$line" | cut -d: -f1)
  val=$(printf '%s' "$line" | sed "s/^[^:]*:[[:space:]]*//; s/[[:space:]]*$//")
  case "$key" in
    enabled|strict|strict_mode|disabled|verbose|dry_run)
      case "$val" in
        true|false|'') ;;
        *) ln=$(grep -n "^$key:" "$F" | head -1 | cut -d: -f1)
           add_finding warn settings-bad-bool settings "$REL" "${ln:-0}" "'$key' should be true or false, got '$val'" ;;
      esac ;;
  esac
done < <(printf '%s\n' "$fm" | grep -E '^[A-Za-z0-9_-]+:')

render_findings "validate-settings.sh" "$F"; exit $?
