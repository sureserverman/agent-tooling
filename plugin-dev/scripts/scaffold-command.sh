#!/usr/bin/env bash
# scaffold-command.sh <plugin-root> <command-name>
# Create commands/<name>.md with valid frontmatter for the LLM to fill in.
# Deterministic structure; never overwrites.
set -eu
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

ROOT="${1:-}"; NAME="${2:-}"
[ -n "$ROOT" ] && [ -n "$NAME" ] || { echo "usage: $0 <plugin-root> <command-name>" >&2; exit 2; }
printf '%s' "$NAME" | grep -Eq '^[a-z0-9]+(-[a-z0-9]+)*$' || { echo "error: name '$NAME' must be kebab-case" >&2; exit 2; }

CMD="$ROOT/commands/$NAME.md"
[ -e "$CMD" ] && { echo "skip: $CMD already exists (no overwrite)"; exit 0; }

mkdir -p "$ROOT/commands"
cat > "$CMD" <<'EOF'
---
description: "TODO: one-line description of what this command does"
argument-hint: "[args]"
allowed-tools: ["Read"]
model: inherit
---

# /__NAME__

TODO: the command prompt body. Keep it tight and decision-rule shaped.

The user invoked this command with: "$ARGUMENTS"
EOF
# substitute the name without disturbing the literal "$ARGUMENTS"
sed -i "s/__NAME__/$NAME/" "$CMD"

echo "scaffolded command at $CMD"
echo "next: set description + allowed-tools to the minimum the command needs; write the prompt body."
echo
bash "$DIR/validate-command.sh" "$CMD"
