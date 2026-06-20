#!/usr/bin/env bash
# Embed _core.md into every host build at the <!-- CORE --> marker.
# Idempotent: running build.sh twice yields the same output.
set -euo pipefail

cd "$(dirname "$0")"

CORE="_core.md"
if [[ ! -f "$CORE" ]]; then
  echo "missing $CORE" >&2
  exit 1
fi

# Adjust this list to match whichever host files you produced.
BUILDS=(
  "claude-code/<AGENT_NAME>.md"
  "codex/AGENTS.md"
  "codex/prompts/<AGENT_NAME>.md"
  "codex/agents/<AGENT_NAME>.toml"
  "cursor/<AGENT_NAME>.mdc"
  "cursor/agents/<AGENT_NAME>.md"
  "opencode/<AGENT_NAME>.md"
)

for f in "${BUILDS[@]}"; do
  if [[ ! -f "$f" ]]; then
    echo "skip  $f (missing)"
    continue
  fi
  tmp="$(mktemp)"
  # Strip previous embedded CORE block (between <!-- CORE:BEGIN --> and <!-- CORE:END -->)
  # and replace the <!-- CORE --> marker line with the current _core.md contents.
  awk -v core="$CORE" '
    BEGIN { in_core = 0 }
    /<!-- CORE:BEGIN -->/ {
      in_core = 1
      while ((getline line < core) > 0) print line
      close(core)
      next
    }
    /<!-- CORE:END -->/   { in_core = 0; next }
    in_core { next }
    /<!-- CORE -->/ {
      while ((getline line < core) > 0) print line
      close(core)
      next
    }
    { print }
  ' "$f" > "$tmp"
  mv "$tmp" "$f"
  echo "built $f"
done
