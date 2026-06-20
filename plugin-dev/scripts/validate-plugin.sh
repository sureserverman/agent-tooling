#!/usr/bin/env bash
# validate-plugin.sh <plugin-root> [--json]
# Orchestrator for the deterministic validation suite. Discovers every component
# in a plugin, runs the matching per-domain validator, merges all findings into
# one JSON contract, and prints a unified verdict.
#
# This is the single entry point the plugin-validator agent and the
# /create-plugin command call. It owns *no* checks of its own beyond discovery
# and the README presence nudge — each domain's rules live in its validator.
set -eu
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$DIR/lib/findings.sh"
have_jq

JSON=0; ARGS=()
for a in "$@"; do case "$a" in --json) JSON=1 ;; *) ARGS+=("$a") ;; esac; done
ROOT="${ARGS[0]:-}"
[ -n "$ROOT" ] || { echo "usage: $0 <plugin-root> [--json]" >&2; exit 2; }
ROOT="$(cd "$ROOT" 2>/dev/null && pwd || true)"
[ -n "$ROOT" ] && [ -d "$ROOT" ] || { echo "error: not a directory: ${ARGS[0]}" >&2; exit 2; }

# Children always emit JSON; the orchestrator re-renders in the requested mode.
CHILD_ARRAYS=()
run() { # <validator-script> <target-relative-to-ROOT>
  local out arr
  out=$(cd "$ROOT" && FINDINGS_JSON=1 bash "$DIR/$1" "$2" --json 2>/dev/null || true)
  arr=$(printf '%s' "$out" | jq -c '.findings' 2>/dev/null || true)
  if [ -z "$arr" ] || [ "$arr" = "null" ]; then
    add_finding error orchestrator-validator-error plugin "$2" 0 "$1 produced no valid JSON for this target"
  else
    CHILD_ARRAYS+=("$arr")
  fi
}

components=()

# Manifest + layout + marketplace consistency (always).
run validate-manifest.sh "."
components+=("manifest")

# Skills.
if [ -d "$ROOT/skills" ]; then
  while IFS= read -r d; do
    [ -f "$ROOT/$d/SKILL.md" ] || continue
    run validate-skill.sh "$d"
    components+=("skill:$(basename "$d")")
  done < <(cd "$ROOT" && find skills -maxdepth 1 -mindepth 1 -type d | sort)
fi

# Commands.
if [ -d "$ROOT/commands" ]; then
  while IFS= read -r f; do
    run validate-command.sh "$f"
    components+=("command:$(basename "$f" .md)")
  done < <(cd "$ROOT" && find commands -maxdepth 1 -name '*.md' | sort)
fi

# Agents.
if [ -d "$ROOT/agents" ]; then
  while IFS= read -r f; do
    run validate-agent.sh "$f"
    components+=("agent:$(basename "$f" .md)")
  done < <(cd "$ROOT" && find agents -maxdepth 1 -name '*.md' | sort)
fi

# Hooks.
if [ -f "$ROOT/hooks/hooks.json" ]; then
  run validate-hooks.sh "hooks/hooks.json"
  components+=("hooks")
fi

# MCP.
if [ -f "$ROOT/.mcp.json" ]; then
  run validate-mcp.sh ".mcp.json"
  components+=("mcp")
fi

# README presence (orchestrator-level nudge).
if [ ! -f "$ROOT/README.md" ]; then
  add_finding info readme-missing readme "README.md" 0 "no README.md at plugin root"
fi

# Merge child arrays + orchestrator's own findings into one array.
MERGED=$(printf '%s\n' "${CHILD_ARRAYS[@]}" "$(_findings_json)" | jq -s 'add // []')

if [ "$JSON" = 1 ]; then
  export FINDINGS_JSON=1
  render_from_json "validate-plugin.sh" "$ROOT" "$MERGED"
  exit $?
fi

# Human mode: discovery summary, then the merged report, then a category roll-up.
echo "Plugin: $(basename "$ROOT")  ($ROOT)"
echo "Components: ${#components[@]} — ${components[*]}"
echo
render_from_json "validate-plugin.sh" "$ROOT" "$MERGED"; rc=$?
if [ "$(printf '%s' "$MERGED" | jq 'length')" -gt 0 ]; then
  echo
  echo "By category:"
  printf '%s' "$MERGED" | jq -r '
    group_by(.category)[]
    | "   " + (.[0].category)
      + ": " + ([.[]|select(.severity=="error")]|length|tostring) + "e/"
      + ([.[]|select(.severity=="warn")]|length|tostring) + "w/"
      + ([.[]|select(.severity=="info")]|length|tostring) + "i"'
fi
exit $rc
