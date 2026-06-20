#!/usr/bin/env bash
# scaffold-plugin.sh <parent-dir> <plugin-name>
# Create a minimal, valid plugin skeleton. Deterministic structure only — the
# LLM fills description/keywords/README body afterward. Never overwrites.
set -eu
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

PARENT="${1:-}"; NAME="${2:-}"
[ -n "$PARENT" ] && [ -n "$NAME" ] || { echo "usage: $0 <parent-dir> <plugin-name>" >&2; exit 2; }
printf '%s' "$NAME" | grep -Eq '^[a-z0-9]+(-[a-z0-9]+)*$' || { echo "error: name '$NAME' must be kebab-case" >&2; exit 2; }

ROOT="$PARENT/$NAME"
[ -e "$ROOT/.claude-plugin/plugin.json" ] && { echo "skip: $ROOT already has a plugin.json (no overwrite)"; exit 0; }

mkdir -p "$ROOT/.claude-plugin"

if [ ! -f "$ROOT/.claude-plugin/plugin.json" ]; then
  cat > "$ROOT/.claude-plugin/plugin.json" <<EOF
{
  "name": "$NAME",
  "description": "TODO: one-line third-person purpose (what this plugin is for)",
  "version": "0.1.0",
  "author": {"name": "", "email": ""},
  "license": "MIT",
  "keywords": ["$NAME"]
}
EOF
fi

[ -f "$ROOT/README.md" ] || cat > "$ROOT/README.md" <<EOF
# $NAME

TODO: what this plugin does, who it's for, and how to install it.
EOF

# LICENSE: reuse a sibling's if the marketplace already has one.
if [ ! -f "$ROOT/LICENSE" ]; then
  sib=$(find "$PARENT" -maxdepth 2 -name LICENSE -not -path "$ROOT/*" 2>/dev/null | head -1 || true)
  [ -n "$sib" ] && cp "$sib" "$ROOT/LICENSE" || true
fi

echo "scaffolded plugin at $ROOT"
echo "next: register it in $PARENT/.claude-plugin/marketplace.json, then add components with scaffold-skill/command/hook."
echo
bash "$DIR/validate-manifest.sh" "$ROOT"
