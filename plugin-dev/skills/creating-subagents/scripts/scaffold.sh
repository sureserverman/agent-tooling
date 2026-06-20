#!/usr/bin/env bash
# Scaffold a multi-host subagent bundle from templates.
# Usage: scaffold.sh <agent-name> [<target-parent-dir>]
#   <agent-name>       — lowercase-hyphen name (e.g. "testing-expert")
#   <target-parent-dir> — where to create <agent-name>/. Defaults to current working dir.
#
# Does NOT overwrite existing files. Run from the directory where you want the bundle.
set -euo pipefail

if [[ $# -lt 1 ]]; then
  echo "usage: $(basename "$0") <agent-name> [<target-parent-dir>]" >&2
  exit 2
fi

NAME="$1"
if [[ ! "$NAME" =~ ^[a-z][a-z0-9-]*$ ]]; then
  echo "error: agent name must be lowercase letters/digits/hyphens, starting with a letter" >&2
  exit 2
fi

PARENT="${2:-$PWD}"
DEST="$PARENT/$NAME"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEMPLATES="$SCRIPT_DIR/../assets/templates"

if [[ ! -d "$TEMPLATES" ]]; then
  echo "error: template dir not found at $TEMPLATES" >&2
  exit 1
fi

mkdir -p "$DEST"/{claude-code,codex/agents,codex/prompts,cursor/agents,opencode}

# Copy a template to a destination path, substituting <AGENT_NAME> and refusing to overwrite.
drop() {
  local src="$1" dst="$2"
  if [[ -e "$dst" ]]; then
    echo "skip  $dst (exists)"
    return
  fi
  sed "s/<AGENT_NAME>/$NAME/g" "$src" > "$dst"
  # Preserve executable bit on scripts.
  case "$dst" in
    *.sh) chmod +x "$dst" ;;
  esac
  echo "wrote $dst"
}

drop "$TEMPLATES/_core.md"                         "$DEST/_core.md"
drop "$TEMPLATES/build.sh"                         "$DEST/build.sh"
drop "$TEMPLATES/install-global.sh"                "$DEST/install-global.sh"
drop "$TEMPLATES/verify.sh"                        "$DEST/verify.sh"
drop "$TEMPLATES/claude-code/agent.md"             "$DEST/claude-code/$NAME.md"
drop "$TEMPLATES/codex/AGENTS.md"                  "$DEST/codex/AGENTS.md"
drop "$TEMPLATES/codex/agents/agent.toml"          "$DEST/codex/agents/$NAME.toml"
drop "$TEMPLATES/codex/prompts/agent.md"           "$DEST/codex/prompts/$NAME.md"
drop "$TEMPLATES/cursor/agent.mdc"                 "$DEST/cursor/$NAME.mdc"
drop "$TEMPLATES/cursor/agents/agent.md"           "$DEST/cursor/agents/$NAME.md"
drop "$TEMPLATES/opencode/agent.md"                "$DEST/opencode/$NAME.md"

cat <<MSG

scaffold complete at: $DEST

next:
  1. fill in $DEST/_core.md (identity, protocols, house rules, schemas, safety)
  2. adjust each host wrapper's frontmatter + Host-affordances section
  3. cd "$DEST" && ./build.sh      # embeds _core.md into every host file
  4. ./install-global.sh            # writes to ~/.claude, ~/.codex, ~/.cursor, ~/.config/opencode
  5. ./verify.sh
MSG
