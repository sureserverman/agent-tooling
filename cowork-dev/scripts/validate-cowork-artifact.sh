#!/usr/bin/env bash
# validate-cowork-artifact.sh <package-dir> [--json]
# Deterministic checks for a Cowork-BOUND plugin package directory — the things
# Cowork's upload/sync pipeline enforces or silently breaks on (June 2026 facts,
# verified 2026-06-09 against claude.com/docs/cowork/guide/plugins and
# support.claude.com articles 13837440 + 13837433). Emits the shared JSON contract.
#
# Checks:
#   - .claude-plugin/plugin.json exists, parses, has a name
#   - name is lowercase-hyphen, ≤64 chars, not on the reserved-name list
#   - uncompressed package ≤200 MB and ≤5,000 files (warn at 80% of either cap)
#   - no npm/pip plugin sources in any marketplace.json (unsupported in Cowork
#     org marketplaces)
#   - no local stdio MCP servers (`command` key) in the package's .mcp.json —
#     Cowork supports MCP only via cloud connectors
#
# Scan exclusions: .git/, node_modules/, and tests/fixtures/ (test data) are
# skipped by the marketplace.json scan; .git/ is excluded from size/file counts
# (it is not part of the uploaded ZIP).
set -eu
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$DIR/lib/findings.sh"
have_jq

JSON=0; ARGS=()
for a in "$@"; do case "$a" in --json) JSON=1 ;; *) ARGS+=("$a") ;; esac; done
[ "$JSON" = 1 ] && export FINDINGS_JSON=1
ROOT="${ARGS[0]:-.}"
ROOT="$(cd "$ROOT" 2>/dev/null && pwd || true)"
[ -n "$ROOT" ] && [ -d "$ROOT" ] || { echo "usage: $0 <package-dir> [--json]" >&2; exit 2; }

# --- Cowork limits (June 2026) ------------------------------------------------
SIZE_LIMIT=$((200 * 1024 * 1024))   # 200 MB uncompressed
FILE_LIMIT=5000                     # files per plugin
SIZE_WARN=$((SIZE_LIMIT * 80 / 100))
FILE_WARN=$((FILE_LIMIT * 80 / 100))
NAME_MAX=64
# Reserved names enforced at upload. The upstream list is longer ("etc." in the
# docs); these are the ones Anthropic names. Keep in sync with article 13837433.
RESERVED_NAMES="claude-code-marketplace anthropic-plugins agent-skills"

# --- 1. manifest + name -------------------------------------------------------
MANIFEST="$ROOT/.claude-plugin/plugin.json"
if [ ! -f "$MANIFEST" ]; then
  add_finding error cowork-manifest-missing cowork-artifact ".claude-plugin/plugin.json" 0 \
    "no .claude-plugin/plugin.json — Cowork rejects packages without a plugin manifest"
elif ! jq empty "$MANIFEST" >/dev/null 2>&1; then
  add_finding error cowork-manifest-unparseable cowork-artifact ".claude-plugin/plugin.json" 0 \
    "plugin.json is not valid JSON"
else
  NAME=$(jq -r '.name // empty' "$MANIFEST")
  if [ -z "$NAME" ]; then
    add_finding error cowork-name-missing cowork-artifact ".claude-plugin/plugin.json" 0 \
      "plugin.json has no name — required for Cowork upload"
  else
    printf '%s' "$NAME" | grep -Eq '^[a-z0-9]+(-[a-z0-9]+)*$' \
      || add_finding error cowork-name-not-lowercase-hyphen cowork-artifact ".claude-plugin/plugin.json" 0 \
           "name '$NAME' is not lowercase-hyphen — Cowork enforces lowercase letters, digits, hyphens"
    [ "${#NAME}" -le "$NAME_MAX" ] \
      || add_finding error cowork-name-too-long cowork-artifact ".claude-plugin/plugin.json" 0 \
           "name '$NAME' is ${#NAME} chars — Cowork caps plugin names at $NAME_MAX"
    for r in $RESERVED_NAMES; do
      if [ "$NAME" = "$r" ]; then
        add_finding error cowork-name-reserved cowork-artifact ".claude-plugin/plugin.json" 0 \
          "name '$NAME' is on Cowork's reserved-name list — pick another name"
      fi
    done
  fi
fi

# --- 2. package size + file count ----------------------------------------------
BYTES=$(find "$ROOT" -path "$ROOT/.git" -prune -o -type f -printf '%s\n' 2>/dev/null | awk '{s+=$1} END {printf "%d", s}')
FILES=$(find "$ROOT" -path "$ROOT/.git" -prune -o -type f -print 2>/dev/null | wc -l)
MB=$((BYTES / 1024 / 1024))

if [ "$BYTES" -gt "$SIZE_LIMIT" ]; then
  add_finding error cowork-package-too-large cowork-artifact "." 0 \
    "uncompressed package is ${MB} MB — Cowork's limit is 200 MB"
elif [ "$BYTES" -gt "$SIZE_WARN" ]; then
  add_finding warn cowork-package-size-near-limit cowork-artifact "." 0 \
    "uncompressed package is ${MB} MB — over 80% of Cowork's 200 MB limit"
fi

if [ "$FILES" -gt "$FILE_LIMIT" ]; then
  add_finding error cowork-package-too-many-files cowork-artifact "." 0 \
    "package has $FILES files — Cowork's limit is $FILE_LIMIT"
elif [ "$FILES" -gt "$FILE_WARN" ]; then
  add_finding warn cowork-package-file-count-near-limit cowork-artifact "." 0 \
    "package has $FILES files — over 80% of Cowork's $FILE_LIMIT-file limit"
fi

# --- 3. npm/pip sources in marketplace.json ------------------------------------
while IFS= read -r mkt; do
  [ -n "$mkt" ] || continue
  rel="${mkt#"$ROOT"/}"
  if ! jq empty "$mkt" >/dev/null 2>&1; then
    add_finding warn cowork-marketplace-unparseable cowork-artifact "$rel" 0 \
      "marketplace.json is not valid JSON — a broken manifest fails org sync (plugins can temporarily disappear)"
    continue
  fi
  while IFS= read -r offender; do
    [ -n "$offender" ] || continue
    add_finding error cowork-marketplace-npm-pip-source cowork-artifact "$rel" 0 \
      "plugin '$offender' uses an npm/pip source — unsupported in Cowork org marketplaces; use a relative path"
  done < <(jq -r '.plugins[]? | select((.source|type)=="object" and ((.source.source=="npm") or (.source.source=="pip"))) | .name // "<unnamed>"' "$mkt")
done < <(find "$ROOT" \( -path "$ROOT/.git" -o -name node_modules -o -path "*/tests/fixtures" \) -prune -o -name marketplace.json -type f -print 2>/dev/null)

# --- 4. local stdio MCP servers -------------------------------------------------
MCP="$ROOT/.mcp.json"
if [ -f "$MCP" ]; then
  if ! jq empty "$MCP" >/dev/null 2>&1; then
    add_finding warn cowork-mcp-unparseable cowork-artifact ".mcp.json" 0 \
      ".mcp.json is not valid JSON"
  else
    while IFS= read -r srv; do
      [ -n "$srv" ] || continue
      add_finding error cowork-mcp-stdio cowork-artifact ".mcp.json" 0 \
        "MCP server '$srv' is local stdio ('command' key) — Cowork supports MCP only via cloud connectors reachable from the public internet"
    done < <(jq -r '(.mcpServers // .) | to_entries[]? | select((.value|type)=="object" and (.value|has("command"))) | .key' "$MCP")
  fi
fi

render_findings "validate-cowork-artifact.sh" "$ROOT"; exit $?
