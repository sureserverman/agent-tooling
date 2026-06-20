#!/usr/bin/env bash
# Install <AGENT_NAME> subagent globally for Claude Code, Codex CLI, Cursor, and OpenCode.
# Run from any directory; paths are resolved relative to this script.
set -euo pipefail

cd "$(dirname "$0")"

MISSING=0
for f in \
  "claude-code/<AGENT_NAME>.md" \
  "codex/agents/<AGENT_NAME>.toml" \
  "cursor/agents/<AGENT_NAME>.md" \
  "opencode/<AGENT_NAME>.md"; do
  [[ -f "$f" ]] || { echo "missing: $f" >&2; MISSING=1; }
done
if [[ $MISSING -eq 1 ]]; then
  echo "error: one or more builds missing. Run ./build.sh first." >&2
  exit 1
fi

install -d ~/.claude/agents
install -d ~/.codex/agents
install -d ~/.cursor/agents
install -d ~/.config/opencode/agents

install -m 0644 claude-code/<AGENT_NAME>.md           ~/.claude/agents/<AGENT_NAME>.md
install -m 0644 codex/agents/<AGENT_NAME>.toml        ~/.codex/agents/<AGENT_NAME>.toml
install -m 0644 cursor/agents/<AGENT_NAME>.md         ~/.cursor/agents/<AGENT_NAME>.md
install -m 0644 opencode/<AGENT_NAME>.md              ~/.config/opencode/agents/<AGENT_NAME>.md

echo "installed:"
echo "  ~/.claude/agents/<AGENT_NAME>.md           (auto-dispatch)"
echo "  ~/.codex/agents/<AGENT_NAME>.toml          (spawn by name via /agent)"
echo "  ~/.cursor/agents/<AGENT_NAME>.md           (auto-dispatch + @mention)"
echo "  ~/.config/opencode/agents/<AGENT_NAME>.md  (auto-dispatch + @mention)"
