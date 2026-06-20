#!/usr/bin/env bash
# validate-manifest.sh <plugin-root> [--json]
# Deterministic checks for .claude-plugin/plugin.json, plugin layout, and
# consistency with the enclosing marketplace.json.
set -eu
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$DIR/lib/findings.sh"
have_jq

JSON=0; ARGS=()
for a in "$@"; do case "$a" in --json) JSON=1 ;; *) ARGS+=("$a") ;; esac; done
[ "$JSON" = 1 ] && export FINDINGS_JSON=1
ROOT="${ARGS[0]:-}"
[ -n "$ROOT" ] || { echo "usage: $0 <plugin-root> [--json]" >&2; exit 2; }
# Resolve to an absolute path so basename works for "." and trailing slashes.
ROOT="$(cd "$ROOT" 2>/dev/null && pwd || echo "${ROOT%/}")"

MANIFEST="$ROOT/.claude-plugin/plugin.json"
REL=".claude-plugin/plugin.json"

if [ ! -f "$MANIFEST" ]; then
  add_finding error manifest-missing manifest "$REL" 0 "no .claude-plugin/plugin.json at plugin root"
  render_findings "validate-manifest.sh" "$ROOT"; exit $?
fi

if ! jq empty "$MANIFEST" >/dev/null 2>&1; then
  add_finding error manifest-unparseable manifest "$REL" 0 "plugin.json is not valid JSON"
  render_findings "validate-manifest.sh" "$ROOT"; exit $?
fi

NAME=$(jq -r '.name // empty' "$MANIFEST")
DESC=$(jq -r '.description // empty' "$MANIFEST")
VER=$(jq -r '.version // empty' "$MANIFEST")

[ -n "$NAME" ] || add_finding error manifest-no-name manifest "$REL" 0 "plugin.json missing required field: name"
[ -n "$DESC" ] || add_finding error manifest-no-description manifest "$REL" 0 "plugin.json missing required field: description"

if [ -n "$NAME" ]; then
  printf '%s' "$NAME" | grep -Eq '^[a-z0-9]+(-[a-z0-9]+)*$' \
    || add_finding warn manifest-name-not-kebab manifest "$REL" 0 "name '$NAME' is not kebab-case (lowercase, hyphen-separated)"
  DIRNAME=$(basename "$ROOT")
  [ "$NAME" = "$DIRNAME" ] \
    || add_finding warn manifest-name-mismatch manifest "$REL" 0 "name '$NAME' does not match plugin directory '$DIRNAME' (discovery expects them equal)"
fi

if [ -n "$VER" ]; then
  printf '%s' "$VER" | grep -Eq '^[0-9]+\.[0-9]+\.[0-9]+([.-].*)?$' \
    || add_finding warn manifest-version-not-semver manifest "$REL" 0 "version '$VER' is not semver (MAJOR.MINOR.PATCH)"
else
  add_finding info manifest-no-version manifest "$REL" 0 "no version field (fine for dev; set one before a stable release)"
fi

# --- layout: components must NOT live inside .claude-plugin/ -----------------
for sub in commands agents skills hooks monitors bin; do
  if [ -d "$ROOT/.claude-plugin/$sub" ]; then
    add_finding error layout-in-claude-plugin layout ".claude-plugin/$sub" 0 "'$sub/' is inside .claude-plugin/ — only plugin.json belongs there; move to plugin root"
  fi
done
for f in .mcp.json .lsp.json; do
  if [ -f "$ROOT/.claude-plugin/$f" ]; then
    add_finding error layout-in-claude-plugin layout ".claude-plugin/$f" 0 "'$f' is inside .claude-plugin/ — move to plugin root"
  fi
done

# --- declared skills[] vs skills/ on disk ------------------------------------
if jq -e '.skills' "$MANIFEST" >/dev/null 2>&1; then
  declared=$(jq -r '.skills[]? | sub("^\\./";"") | sub("^skills/";"") | sub("/$";"")' "$MANIFEST" | sort -u)
  ondisk=""
  if [ -d "$ROOT/skills" ]; then
    ondisk=$(find "$ROOT/skills" -maxdepth 1 -mindepth 1 -type d -exec basename {} \; | sort -u)
  fi
  while IFS= read -r d; do
    [ -n "$d" ] || continue
    printf '%s\n' "$ondisk" | grep -qxF "$d" \
      || add_finding warn manifest-skill-not-on-disk manifest "$REL" 0 "skills[] lists '$d' but skills/$d/ does not exist"
  done <<< "$declared"
  while IFS= read -r d; do
    [ -n "$d" ] || continue
    printf '%s\n' "$declared" | grep -qxF "$d" \
      || add_finding info manifest-skill-not-declared manifest "$REL" 0 "skills/$d/ exists but is not listed in plugin.json skills[]"
  done <<< "$ondisk"
fi

# --- marketplace.json consistency (parent dir) -------------------------------
MKT="$(dirname "$ROOT")/.claude-plugin/marketplace.json"
if [ -f "$MKT" ] && jq empty "$MKT" >/dev/null 2>&1; then
  base=$(basename "$ROOT")
  entry=$(jq -c --arg s "./$base" '.plugins[]? | select(.source==$s)' "$MKT" 2>/dev/null | head -1)
  if [ -n "$entry" ]; then
    mname=$(printf '%s' "$entry" | jq -r '.name // empty')
    mver=$(printf '%s' "$entry" | jq -r '.version // empty')
    [ -z "$mname" ] || [ "$mname" = "$NAME" ] \
      || add_finding warn manifest-marketplace-name-drift manifest "$REL" 0 "marketplace.json registers this plugin as '$mname' but plugin.json name is '$NAME'"
    [ -z "$mver" ] || [ -z "$VER" ] || [ "$mver" = "$VER" ] \
      || add_finding warn manifest-marketplace-version-drift manifest "$REL" 0 "marketplace.json version '$mver' != plugin.json version '$VER'"
  else
    add_finding info manifest-not-registered manifest "$REL" 0 "no marketplace.json entry with source './$base' (register the plugin to make it installable)"
  fi
fi

render_findings "validate-manifest.sh" "$ROOT"; exit $?
