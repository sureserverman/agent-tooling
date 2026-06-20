#!/usr/bin/env bash
# scaffold-hook.sh <plugin-root> <event> [matcher]
# Add a command hook for <event> to hooks/hooks.json (created/merged) and
# generate a guarded hooks/<event>.sh template referenced via
# ${CLAUDE_PLUGIN_ROOT}. Deterministic; never overwrites an existing script.
set -eu
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

VALID_EVENTS="SessionStart SessionEnd UserPromptSubmit PreToolUse PostToolUse PostToolUseFailure PostToolBatch PermissionRequest Stop StopFailure Notification UserPromptExpansion CwdChanged FileChanged SubagentStart SubagentStop"

ROOT="${1:-}"; EVENT="${2:-}"; MATCHER="${3:-}"
[ -n "$ROOT" ] && [ -n "$EVENT" ] || { echo "usage: $0 <plugin-root> <event> [matcher]" >&2; exit 2; }
case " $VALID_EVENTS " in *" $EVENT "*) ;; *) echo "error: '$EVENT' is not a known 2026 hook event" >&2; exit 2 ;; esac

mkdir -p "$ROOT/hooks"
HOOKS="$ROOT/hooks/hooks.json"
SCRIPT="$ROOT/hooks/$EVENT.sh"

# --- generate the hook script (guarded for Stop-family) ----------------------
if [ ! -f "$SCRIPT" ]; then
  {
    echo '#!/usr/bin/env bash'
    echo "# $EVENT hook"
    echo 'set -eu'
    echo 'input=$(cat)   # hooks receive a JSON event on stdin'
    if [ "$EVENT" = "Stop" ] || [ "$EVENT" = "StopFailure" ]; then
      echo '# guard against an infinite stop loop'
      echo 'if [ "$(printf "%s" "$input" | jq -r ".stop_hook_active // false")" = "true" ]; then exit 0; fi'
    fi
    echo '# TODO: read fields, e.g. tool=$(printf "%s" "$input" | jq -r ".tool_name // empty")'
    echo '# Exit 0 to allow; exit 2 to block (PreToolUse) and write a reason to stderr.'
    echo 'exit 0'
  } > "$SCRIPT"
  chmod +x "$SCRIPT"
  echo "scaffolded hook script at $SCRIPT"
else
  echo "skip: $SCRIPT already exists (no overwrite)"
fi

# --- merge an entry into hooks.json ------------------------------------------
[ -f "$HOOKS" ] && jq empty "$HOOKS" >/dev/null 2>&1 || echo '{"hooks":{}}' > "$HOOKS"

group=$(jq -nc --arg cmd '${CLAUDE_PLUGIN_ROOT}/hooks/'"$EVENT"'.sh' --arg m "$MATCHER" '
  {hooks: [ {type: "command", command: $cmd, timeout: 10} ]}
  + (if $m == "" then {} else {matcher: $m} end)')

tmp=$(mktemp)
jq --arg e "$EVENT" --argjson g "$group" '
  .hooks = (.hooks // {})
  | .hooks[$e] = ((.hooks[$e] // []) + [$g])' "$HOOKS" > "$tmp" && mv "$tmp" "$HOOKS"

echo "registered $EVENT hook in $HOOKS"
echo
bash "$DIR/validate-hooks.sh" "$HOOKS"
