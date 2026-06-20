#!/usr/bin/env bash
# validate-command.sh <path-to-command.md> [--json]
# Deterministic checks for a slash command: frontmatter, description, model
# enum, tool scoping, $ARGUMENTS quoting, hardcoded paths.
set -eu
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$DIR/lib/findings.sh"
have_jq

JSON=0; ARGS=()
for a in "$@"; do case "$a" in --json) JSON=1 ;; *) ARGS+=("$a") ;; esac; done
[ "$JSON" = 1 ] && export FINDINGS_JSON=1
CMD="${ARGS[0]:-}"
[ -n "$CMD" ] || { echo "usage: $0 <command.md> [--json]" >&2; exit 2; }
REL="$CMD"

if [ ! -f "$CMD" ]; then
  add_finding error cmd-missing command "$REL" 0 "command file not found"
  render_findings "validate-command.sh" "$CMD"; exit $?
fi
if ! has_closing_fence "$CMD"; then
  add_finding error cmd-no-frontmatter command "$REL" 1 "command must open and close a YAML frontmatter block (---)"
  render_findings "validate-command.sh" "$CMD"; exit $?
fi

DESC=$(frontmatter_field "$CMD" description)
MODEL=$(frontmatter_field "$CMD" model)
TOOLS=$(frontmatter_field "$CMD" allowed-tools)

[ -n "$DESC" ] || add_finding error cmd-no-description command "$REL" 0 "frontmatter missing required field: description"

if [ -n "$MODEL" ]; then
  case "$MODEL" in
    inherit|haiku|sonnet|opus) ;;
    *) add_finding warn cmd-model-unknown command "$REL" 0 "model '$MODEL' not in {inherit,haiku,sonnet,opus}" ;;
  esac
fi

# bare "*" in allowed-tools = unrestricted; flag on commands (orchestrators may
# legitimately need broad tools — hence warn, not error, for the LLM to judge).
if printf '%s' "$TOOLS" | grep -Eq '(^|[][ ",])\*([][ ",]|$)'; then
  add_finding warn cmd-wildcard-tools command "$REL" 0 "allowed-tools includes '*' (unrestricted) — scope to the tools the command actually uses unless it is an orchestrator"
fi

# $ARGUMENTS quoting — only meaningful when the command can run a shell.
if printf '%s' "$TOOLS" | grep -q 'Bash'; then
  if grep -nE '\$ARGUMENTS' "$CMD" | grep -vE '"\$ARGUMENTS"|`[^`]*\$ARGUMENTS[^`]*`' >/dev/null; then
    ln=$(grep -nE '\$ARGUMENTS' "$CMD" | grep -vE '"\$ARGUMENTS"|`[^`]*\$ARGUMENTS' | head -1 | cut -d: -f1)
    add_finding warn cmd-arguments-unquoted command "$REL" "${ln:-0}" "unquoted \$ARGUMENTS in a Bash-capable command — quote as \"\$ARGUMENTS\" to avoid shell injection/splitting"
  fi
fi

# hardcoded absolute home paths
if grep -nE '/home/|/Users/' "$CMD" >/dev/null; then
  ln=$(grep -nE '/home/|/Users/' "$CMD" | head -1 | cut -d: -f1)
  add_finding warn cmd-hardcoded-path command "$REL" "${ln:-0}" "hardcoded home path — use \${CLAUDE_PLUGIN_ROOT} or \${CLAUDE_PROJECT_DIR} / a relative path"
fi

render_findings "validate-command.sh" "$CMD"; exit $?
