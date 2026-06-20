#!/usr/bin/env bash
# install-kit.sh <target-plugin-root> [--force]
# Vendor the plugin-dev determinism kit into a target plugin's scripts/ so it
# owns a self-contained deterministic lane: the shared finding contract
# (lib/findings.sh), the generic orchestrator (validate.sh), and a boundary doc.
# Idempotent and non-destructive — the target's own validate-*.sh domain
# validators are never touched. --force refreshes only the kit-owned generic
# files (findings.sh, validate.sh) to the current plugin-dev version.
set -eu
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

FORCE=0; ARGS=()
for a in "$@"; do case "$a" in --force) FORCE=1 ;; *) ARGS+=("$a") ;; esac; done
ROOT="${ARGS[0]:-}"
[ -n "$ROOT" ] || { echo "usage: $0 <target-plugin-root> [--force]" >&2; exit 2; }
ROOT="$(cd "$ROOT" 2>/dev/null && pwd || true)"
[ -n "$ROOT" ] && [ -d "$ROOT" ] || { echo "error: not a directory: ${ARGS[0]:-}" >&2; exit 2; }

DEST="$ROOT/scripts"
mkdir -p "$DEST/lib"

# plugin name for the boundary doc
NAME=$(basename "$ROOT")
if [ -f "$ROOT/.claude-plugin/plugin.json" ] && command -v jq >/dev/null 2>&1; then
  n=$(jq -r '.name // empty' "$ROOT/.claude-plugin/plugin.json" 2>/dev/null || true)
  [ -n "$n" ] && NAME="$n"
fi

# kit-owned generic files: copy if missing, or refresh on --force
copy_generic() { # <src> <dest>
  if [ ! -f "$2" ] || [ "$FORCE" = 1 ]; then
    cp "$1" "$2"; echo "  $([ "$FORCE" = 1 ] && echo refreshed || echo installed): ${2#"$ROOT"/}"
  else
    echo "  kept (use --force to refresh): ${2#"$ROOT"/}"
  fi
}
copy_generic "$DIR/lib/findings.sh" "$DEST/lib/findings.sh"
copy_generic "$DIR/kit/validate.sh" "$DEST/validate.sh"
chmod +x "$DEST/validate.sh" "$DEST/lib/findings.sh"

# boundary doc: never overwrite (it gets specialized per plugin)
if [ ! -f "$DEST/README.md" ]; then
  sed "s/__PLUGIN__/$NAME/g" "$DIR/kit/README.md" > "$DEST/README.md"
  echo "  installed: scripts/README.md"
else
  echo "  kept: scripts/README.md"
fi

echo
echo "kit installed in $DEST"
echo "next: add domain validators with scaffold-validator.sh \"$DEST\" <domain>, then rewire this plugin's agents/commands to run scripts/validate.sh."
echo
bash "$DEST/validate.sh" "$ROOT"
