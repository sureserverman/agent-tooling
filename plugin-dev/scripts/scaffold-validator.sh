#!/usr/bin/env bash
# scaffold-validator.sh <target-scripts-dir> <domain>
# Generate a new domain validator (validate-<domain>.sh) on the shared finding
# contract, inside a scripts/ dir that already has the kit (lib/findings.sh).
# Deterministic structure; the actual checks are filled by the author/LLM.
# Never overwrites.
set -eu

SDIR="${1:-}"; DOMAIN="${2:-}"
[ -n "$SDIR" ] && [ -n "$DOMAIN" ] || { echo "usage: $0 <target-scripts-dir> <domain>" >&2; exit 2; }
printf '%s' "$DOMAIN" | grep -Eq '^[a-z0-9]+(-[a-z0-9]+)*$' || { echo "error: domain '$DOMAIN' must be kebab-case" >&2; exit 2; }
SDIR="${SDIR%/}"
[ -f "$SDIR/lib/findings.sh" ] || { echo "error: $SDIR has no lib/findings.sh — run install-kit.sh <plugin-root> first" >&2; exit 2; }

OUT="$SDIR/validate-$DOMAIN.sh"
[ -e "$OUT" ] && { echo "skip: $OUT already exists (no overwrite)"; exit 0; }

cat > "$OUT" <<'EOF'
#!/usr/bin/env bash
# validate-__DOMAIN__.sh <plugin-root> [--json]
# Deterministic checks for the __DOMAIN__ domain. Emits the shared JSON contract.
set -eu
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$DIR/lib/findings.sh"
have_jq

JSON=0; ARGS=()
for a in "$@"; do case "$a" in --json) JSON=1 ;; *) ARGS+=("$a") ;; esac; done
[ "$JSON" = 1 ] && export FINDINGS_JSON=1
ROOT="${ARGS[0]:-.}"
ROOT="$(cd "$ROOT" 2>/dev/null && pwd || true)"
[ -n "$ROOT" ] && [ -d "$ROOT" ] || { echo "usage: $0 <plugin-root> [--json]" >&2; exit 2; }

# TODO: add deterministic checks for the __DOMAIN__ domain.
#   Only decidable checks belong here — parse, field presence, enum, count, regex.
#   For each finding, call:
#     add_finding <error|warn|info> <rule-id> __DOMAIN__ "<relpath>" <line|0> "<message>"
#   Keep <rule-id> stable + kebab-case; this plugin's agents key off it.
#   Judgment (taste, rewriting, design) stays in the skills/agents, which run
#   this script and consume its JSON instead of re-deriving the rules.
#
# Example:
#   f="$ROOT/Cargo.toml"
#   [ -f "$f" ] || add_finding error __DOMAIN__-missing-manifest __DOMAIN__ "Cargo.toml" 0 "no Cargo.toml at crate root"

render_findings "validate-__DOMAIN__.sh" "$ROOT"; exit $?
EOF
sed -i "s/__DOMAIN__/$DOMAIN/g" "$OUT"
chmod +x "$OUT"

echo "scaffolded domain validator at $OUT"
echo "next: replace the TODO with real checks, then it is auto-discovered by scripts/validate.sh."
echo
# prove it parses + runs clean against the enclosing plugin root
bash "$OUT" "$(dirname "$SDIR")"
