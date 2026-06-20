#!/usr/bin/env bash
# Verify <AGENT_NAME> subagent is installed on every host.
set -euo pipefail

FAIL=0
check() {
  local path="$1" label="$2"
  if [[ -f "$path" ]]; then
    printf "%-12s %s\n" "ok" "$path"
  else
    printf "%-12s %s\n" "MISSING" "$path"
    FAIL=1
  fi
}

check "$HOME/.claude/agents/<AGENT_NAME>.md"          "claude-code"
check "$HOME/.codex/agents/<AGENT_NAME>.toml"         "codex"
check "$HOME/.cursor/agents/<AGENT_NAME>.md"          "cursor"
check "$HOME/.config/opencode/agents/<AGENT_NAME>.md" "opencode"

if [[ $FAIL -eq 0 ]]; then
  echo
  echo "all hosts ok."
else
  echo
  echo "one or more hosts missing. Run ./install-global.sh." >&2
  exit 1
fi
