#!/usr/bin/env bash
# validate-cursor-artifact.sh <artifact-dir> [--json]
# Deterministic checks for a Cursor-BOUND artifact directory (a Cursor plugin,
# or a repo's .cursor/ payload) — the things Cursor enforces or silently breaks
# on (June 2026 facts, verified 2026-06-09 against cursor.com/docs/plugins,
# /docs/context/rules, /docs/skills, /docs/hooks.md; Cursor 3.7). Emits the
# shared JSON contract.
#
# Checks:
#   - .cursor-plugin/plugin.json exists, parses, has a "name"
#   - every rules/*.mdc has parseable YAML frontmatter (python3 + pyyaml);
#     alwaysApply:false with no description and no globs → accidental
#     manual-only rule (warn)
#   - plain .md files inside a rules/ dir — Cursor silently ignores them
#   - every skills/*/SKILL.md frontmatter name equals its directory name
#   - hooks.json (if present): parses, has an integer "version", event names
#     within the known camelCase set (~22); unknown name → warn
#
# Scan exclusions: .git/, node_modules/, and tests/fixtures/ (test data) are
# skipped by every recursive scan.
set -eu
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$DIR/lib/findings.sh"
have_jq

JSON=0; ARGS=()
for a in "$@"; do case "$a" in --json) JSON=1 ;; *) ARGS+=("$a") ;; esac; done
[ "$JSON" = 1 ] && export FINDINGS_JSON=1
ROOT="${ARGS[0]:-.}"
ROOT="$(cd "$ROOT" 2>/dev/null && pwd || true)"
[ -n "$ROOT" ] && [ -d "$ROOT" ] || { echo "usage: $0 <artifact-dir> [--json]" >&2; exit 2; }

# prune expression shared by every recursive scan
scan() { # <extra find args…>
  find "$ROOT" \( -name .git -o -name node_modules -o -path "*/tests/fixtures" \) -prune -o "$@" -print 2>/dev/null
}

# --- Known hook events (camelCase, Cursor 3.7) ---------------------------------
KNOWN_EVENTS="sessionStart sessionEnd preToolUse postToolUse postToolUseFailure \
subagentStart subagentStop beforeShellExecution afterShellExecution \
beforeMCPExecution afterMCPExecution beforeReadFile afterFileEdit \
beforeSubmitPrompt preCompact afterAgentResponse afterAgentThought stop \
beforeTabFileRead afterTabFileEdit workspaceOpen"

# --- 1. manifest ---------------------------------------------------------------
MANIFEST="$ROOT/.cursor-plugin/plugin.json"
if [ ! -f "$MANIFEST" ]; then
  add_finding error cursor-manifest-missing cursor-artifact ".cursor-plugin/plugin.json" 0 \
    "no .cursor-plugin/plugin.json — Cursor plugins require this manifest (note: NOT .claude-plugin/)"
elif ! jq empty "$MANIFEST" >/dev/null 2>&1; then
  add_finding error cursor-manifest-unparseable cursor-artifact ".cursor-plugin/plugin.json" 0 \
    "plugin.json is not valid JSON"
else
  NAME=$(jq -r '.name // empty' "$MANIFEST")
  [ -n "$NAME" ] || add_finding error cursor-manifest-name-missing cursor-artifact ".cursor-plugin/plugin.json" 0 \
    "plugin.json has no name — the only required manifest field"
fi

# --- 2. rules/*.mdc frontmatter (python3 + pyyaml) -------------------------------
# For each .mdc under a rules/ dir: frontmatter must parse as YAML; an
# alwaysApply:false rule with neither description nor globs never auto-applies.
check_mdc() { # <file>
  python3 - "$1" <<'PY'
import sys, yaml
path = sys.argv[1]
text = open(path, encoding="utf-8", errors="replace").read()
lines = text.split("\n")
if not lines or lines[0].strip() != "---":
    print("BROKEN no frontmatter fence"); sys.exit(0)
try:
    end = next(i for i in range(1, len(lines)) if lines[i].strip() == "---")
except StopIteration:
    print("BROKEN unclosed frontmatter fence"); sys.exit(0)
try:
    fm = yaml.safe_load("\n".join(lines[1:end]))
except yaml.YAMLError as e:
    print("BROKEN " + str(e).split("\n")[0]); sys.exit(0)
fm = fm or {}
if not isinstance(fm, dict):
    print("BROKEN frontmatter is not a YAML mapping"); sys.exit(0)
if fm.get("alwaysApply") is False and not fm.get("description") and not fm.get("globs"):
    print("MANUAL"); sys.exit(0)
print("OK")
PY
}

while IFS= read -r mdc; do
  [ -n "$mdc" ] || continue
  rel="${mdc#"$ROOT"/}"
  res=$(check_mdc "$mdc" 2>/dev/null || echo "BROKEN python3/pyyaml unavailable or crashed")
  case "$res" in
    OK) ;;
    MANUAL)
      add_finding warn cursor-rule-manual-only cursor-artifact "$rel" 0 \
        "alwaysApply: false with no description and no globs — accidental manual-only rule; it never auto-applies" ;;
    BROKEN*)
      add_finding error cursor-mdc-frontmatter cursor-artifact "$rel" 0 \
        "unparseable .mdc YAML frontmatter — ${res#BROKEN }" ;;
  esac
done < <(scan -type f -path "*/rules/*.mdc")

# --- 3. plain .md inside rules/ — silently ignored by Cursor --------------------
while IFS= read -r md; do
  [ -n "$md" ] || continue
  rel="${md#"$ROOT"/}"
  add_finding error cursor-rules-md-ignored cursor-artifact "$rel" 0 \
    "plain .md inside a rules/ dir — Cursor only loads .mdc; this file is silently ignored (rename to .mdc)"
done < <(scan -type f -path "*/rules/*.md")

# --- 4. skills/*/SKILL.md name == directory ------------------------------------
while IFS= read -r sk; do
  [ -n "$sk" ] || continue
  rel="${sk#"$ROOT"/}"
  dirname_part="$(basename "$(dirname "$sk")")"
  fm_name="$(frontmatter_field "$sk" name)"
  if [ -n "$fm_name" ] && [ "$fm_name" != "$dirname_part" ]; then
    add_finding error cursor-skill-name-mismatch cursor-artifact "$rel" 0 \
      "frontmatter name '$fm_name' != directory '$dirname_part' — breaks skill discovery"
  fi
done < <(scan -type f -path "*/skills/*/SKILL.md")

# --- 5. hooks.json -------------------------------------------------------------
check_hooks() { # <file> <rel>
  local hk="$1" rel="$2"
  if ! jq empty "$hk" >/dev/null 2>&1; then
    add_finding error cursor-hooks-unparseable cursor-artifact "$rel" 0 \
      "hooks.json is not valid JSON"
    return
  fi
  if [ "$(jq -r '.version | type' "$hk")" != "number" ] || \
     [ "$(jq -r '.version == (.version | floor)' "$hk")" != "true" ]; then
    add_finding error cursor-hooks-version cursor-artifact "$rel" 0 \
      "hooks.json needs an integer top-level \"version\" field (currently: $(jq -c '.version // "missing"' "$hk"))"
  fi
  while IFS= read -r ev; do
    [ -n "$ev" ] || continue
    known=0
    for k in $KNOWN_EVENTS; do [ "$ev" = "$k" ] && known=1 && break; done
    [ "$known" = 1 ] || add_finding warn cursor-hook-unknown-event cursor-artifact "$rel" 0 \
      "unknown hook event '$ev' — not in Cursor's camelCase event set; the hook never fires (PascalCase ported from Claude Code?)"
  done < <(jq -r '.hooks // {} | keys[]' "$hk" 2>/dev/null)
}

while IFS= read -r hk; do
  [ -n "$hk" ] || continue
  check_hooks "$hk" "${hk#"$ROOT"/}"
done < <(scan -type f -name hooks.json)

render_findings "validate-cursor-artifact.sh" "$ROOT"; exit $?
