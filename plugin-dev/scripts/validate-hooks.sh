#!/usr/bin/env bash
# validate-hooks.sh <hooks.json | plugin-root> [--json]
# Merges the old hook-linter.sh + validate-hook-schema.sh into one validator
# with the current 2026 event list. Checks hooks.json structure, event names,
# hook types, ${CLAUDE_PLUGIN_ROOT} usage, Stop-guard, timeout sanity, and
# (when resolvable) the referenced bundled scripts.
set -eu
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$DIR/lib/findings.sh"
have_jq

# Single source of truth for the canonical 2026 hook events. Keep in sync with
# the list quoted in agents/plugin-validator.md and references/events.md.
VALID_EVENTS="SessionStart SessionEnd UserPromptSubmit PreToolUse PostToolUse PostToolUseFailure PostToolBatch PermissionRequest Stop StopFailure Notification UserPromptExpansion CwdChanged FileChanged SubagentStart SubagentStop"
# Events on which a prompt-type hook is meaningful.
PROMPT_EVENTS="Stop SubagentStop UserPromptSubmit PreToolUse"

JSON=0; ARGS=()
for a in "$@"; do case "$a" in --json) JSON=1 ;; *) ARGS+=("$a") ;; esac; done
[ "$JSON" = 1 ] && export FINDINGS_JSON=1
TARGET="${ARGS[0]:-}"
[ -n "$TARGET" ] || { echo "usage: $0 <hooks.json|plugin-root> [--json]" >&2; exit 2; }

if [ -d "$TARGET" ]; then HOOKS="$TARGET/hooks/hooks.json"; PLUGIN_ROOT="$TARGET"
else HOOKS="$TARGET"; PLUGIN_ROOT="$(cd "$(dirname "$HOOKS")/.." && pwd)"; fi
REL="$HOOKS"

if [ ! -f "$HOOKS" ]; then
  add_finding error hook-missing hook "$REL" 0 "hooks.json not found"
  render_findings "validate-hooks.sh" "$TARGET"; exit $?
fi
if ! jq empty "$HOOKS" >/dev/null 2>&1; then
  add_finding error hook-unparseable hook "$REL" 0 "hooks.json is not valid JSON"
  render_findings "validate-hooks.sh" "$TARGET"; exit $?
fi

in_list() { case " $1 " in *" $2 "*) return 0 ;; *) return 1 ;; esac; }

# Flatten one row per hook, fields joined by U+001F. A non-whitespace separator
# is required: with a tab/space IFS, empty fields (e.g. an absent timeout)
# collapse and shift every later column.
rows=$(jq -r '
  (.hooks // .) as $h
  | $h | to_entries[]
  | .key as $event
  | (.value // []) | .[]?
  | (.hooks // []) | .[]?
  | [$event, (.type // ""), ((.timeout // "")|tostring), (.command // ""), (.prompt // "")]
  | join("")
' "$HOOKS")

if [ -z "$rows" ]; then
  add_finding warn hook-empty hook "$REL" 0 "hooks.json declares no hooks"
fi

while IFS=$'\037' read -r event type timeout command prompt; do
  [ -n "$event" ] || continue

  in_list "$VALID_EVENTS" "$event" \
    || add_finding error hook-event-unknown hook "$REL" 0 "event '$event' is not a known 2026 hook event"

  case "$type" in
    command)
      if [ -z "$command" ]; then
        add_finding error hook-command-missing hook "$REL" 0 "[$event] command-type hook has no 'command'"
      else
        # bundled-script path hygiene
        if printf '%s' "$command" | grep -Eq '\.(sh|py|js|ts)( |$|"|\047)' || printf '%s' "$command" | grep -q '/hooks/'; then
          if ! printf '%s' "$command" | grep -q '${CLAUDE_PLUGIN_ROOT}'; then
            if printf '%s' "$command" | grep -Eq '(^| )(/home/|/Users/|\./)'; then
              add_finding error hook-path-not-root hook "$REL" 0 "[$event] hook script uses an absolute/relative path — reference it via \${CLAUDE_PLUGIN_ROOT}"
            fi
          fi
          # resolve and lint the referenced script if we can find it
          spath=$(printf '%s' "$command" | grep -oE '(\$\{CLAUDE_PLUGIN_ROOT\}|[^ "'\'']*)/hooks/[^ "'\'']+\.(sh|py)' | head -1)
          if [ -n "$spath" ]; then
            rpath=${spath/\$\{CLAUDE_PLUGIN_ROOT\}/$PLUGIN_ROOT}
            if [ -e "$rpath" ]; then
              # Stop / StopFailure must guard against re-trigger loops
              if { [ "$event" = "Stop" ] || [ "$event" = "StopFailure" ]; } \
                 && ! grep -q 'stop_hook_active' "$rpath" \
                 && ! printf '%s' "$command" | grep -q 'stop_hook_active'; then
                add_finding error hook-stop-no-guard hook "${rpath#"$PLUGIN_ROOT"/}" 0 "[$event] no stop_hook_active guard — risks an infinite stop loop"
              fi
            else
              add_finding warn hook-script-missing hook "$REL" 0 "[$event] referenced script '$spath' does not exist"
            fi
          fi
        fi
        # inline Stop command with no guard
        if { [ "$event" = "Stop" ] || [ "$event" = "StopFailure" ]; } \
           && ! printf '%s' "$command" | grep -q '/hooks/' \
           && ! printf '%s' "$command" | grep -q 'stop_hook_active'; then
          add_finding error hook-stop-no-guard hook "$REL" 0 "[$event] inline command has no stop_hook_active guard — risks an infinite stop loop"
        fi
      fi
      ;;
    prompt)
      [ -n "$prompt" ] || add_finding error hook-prompt-missing hook "$REL" 0 "[$event] prompt-type hook has no 'prompt'"
      in_list "$PROMPT_EVENTS" "$event" \
        || add_finding warn hook-prompt-event hook "$REL" 0 "[$event] prompt-type hooks are typically only honored on: $PROMPT_EVENTS"
      ;;
    "")
      add_finding error hook-type-missing hook "$REL" 0 "[$event] hook has no 'type' (expected command or prompt)"
      ;;
    *)
      add_finding error hook-type-unknown hook "$REL" 0 "[$event] hook type '$type' is not 'command' or 'prompt'"
      ;;
  esac

  if [ -n "$timeout" ]; then
    case "$timeout" in
      *[!0-9]*) add_finding error hook-timeout-nan hook "$REL" 0 "[$event] timeout '$timeout' is not numeric (seconds)" ;;
      *) [ "$timeout" -gt 600 ] && add_finding warn hook-timeout-high hook "$REL" 0 "[$event] timeout ${timeout}s is unusually high (>600s)"
         [ "$timeout" -lt 1 ]   && add_finding warn hook-timeout-low  hook "$REL" 0 "[$event] timeout ${timeout}s is unusually low" ;;
    esac
  fi
done <<< "$rows"

render_findings "validate-hooks.sh" "$TARGET"; exit $?
