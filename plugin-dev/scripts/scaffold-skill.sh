#!/usr/bin/env bash
# scaffold-skill.sh <plugin-root> <skill-name>
# Create skills/<name>/SKILL.md with valid frontmatter for the LLM to fill in.
# Deterministic structure; never overwrites.
set -eu
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

ROOT="${1:-}"; NAME="${2:-}"
[ -n "$ROOT" ] && [ -n "$NAME" ] || { echo "usage: $0 <plugin-root> <skill-name>" >&2; exit 2; }
printf '%s' "$NAME" | grep -Eq '^[a-z0-9]+(-[a-z0-9]+)*$' || { echo "error: name '$NAME' must be kebab-case" >&2; exit 2; }

SDIR="$ROOT/skills/$NAME"
SKILL="$SDIR/SKILL.md"
[ -e "$SKILL" ] && { echo "skip: $SKILL already exists (no overwrite)"; exit 0; }

mkdir -p "$SDIR"
cat > "$SKILL" <<EOF
---
name: $NAME
description: TODO third-person trigger. "Use when …" — describe WHEN to use this, with concrete trigger phrases. State the WHAT, never the HOW (no steps, no procedure — that leaks).
---

# $NAME

TODO: the actual workflow / instructions live here in the body. Put the "how"
here — Claude reads the body once the description has triggered the skill.

## When this applies

TODO

## Steps / guidance

TODO
EOF

echo "scaffolded skill at $SKILL"
echo "next: write the description (when, not how) and the body (the how); add references/ for depth."
echo
bash "$DIR/validate-skill.sh" "$SDIR"
