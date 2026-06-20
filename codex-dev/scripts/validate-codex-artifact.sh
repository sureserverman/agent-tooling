#!/usr/bin/env bash
# validate-codex-artifact.sh <artifact-dir> [--json]
# Deterministic checks for a Codex-BOUND artifact directory — a Codex plugin,
# skills tree, agents dir, or config drop (June 2026 facts, verified 2026-06-09
# against developers.openai.com/codex config-reference + config-advanced +
# hooks + mcp + plugins, Codex CLI v0.139.0). Emits the shared JSON contract.
#
# Checks:
#   - .codex-plugin/plugin.json exists, parses, has a name
#   - manifest component pointers (skills/mcpServers/apps/hooks) start with
#     "./" and resolve to existing paths
#   - skills/*/SKILL.md frontmatter parses as YAML and has name + description
#   - agents/*.toml parse (tomllib) and carry name + description +
#     developer_instructions
#   - every config.toml parses (tomllib) and contains NO legacy [profiles.*]
#     table and NO top-level profile= key (removed in v0.134.0 — startup fails)
#   - every hooks.json parses and uses only the 10 known lifecycle events
#
# Scan exclusions: .git/, node_modules/, and tests/fixtures/ (test data) are
# pruned from the config.toml and hooks.json scans so self-scans stay clean.
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

# The 10 hook lifecycle events (engine v0.114.0, current at v0.139.0).
KNOWN_EVENTS='["SessionStart","SubagentStart","UserPromptSubmit","PreToolUse","PermissionRequest","PostToolUse","PreCompact","PostCompact","SubagentStop","Stop"]'

PY=0
command -v python3 >/dev/null 2>&1 && PY=1
[ "$PY" = 1 ] || add_finding warn codex-python-missing codex-artifact "." 0 \
  "python3 not found — TOML and YAML-frontmatter checks skipped"

prune_find() { # <name-pattern> — find files, skipping .git/node_modules/tests/fixtures
  find "$ROOT" \( -path "$ROOT/.git" -o -name node_modules -o -path "*/tests/fixtures" \) -prune \
    -o -name "$1" -type f -print 2>/dev/null
}

# --- 1. manifest + component pointers -----------------------------------------
MANIFEST="$ROOT/.codex-plugin/plugin.json"
if [ ! -f "$MANIFEST" ]; then
  add_finding error codex-manifest-missing codex-artifact ".codex-plugin/plugin.json" 0 \
    "no .codex-plugin/plugin.json — Codex plugins require the manifest (NOT .claude-plugin/)"
elif ! jq empty "$MANIFEST" >/dev/null 2>&1; then
  add_finding error codex-manifest-unparseable codex-artifact ".codex-plugin/plugin.json" 0 \
    "plugin.json is not valid JSON"
else
  NAME=$(jq -r '.name // empty' "$MANIFEST")
  [ -n "$NAME" ] || add_finding error codex-manifest-name-missing codex-artifact ".codex-plugin/plugin.json" 0 \
    "plugin.json has no name — required"
  while IFS=$'\t' read -r field ptr; do
    [ -n "$ptr" ] || continue
    case "$ptr" in
      ./*)
        [ -e "$ROOT/${ptr#./}" ] || add_finding error codex-manifest-pointer codex-artifact ".codex-plugin/plugin.json" 0 \
          "$field pointer '$ptr' does not resolve to an existing path"
        ;;
      *)
        add_finding error codex-manifest-pointer codex-artifact ".codex-plugin/plugin.json" 0 \
          "$field pointer '$ptr' must be a './'-prefixed relative path"
        ;;
    esac
  done < <(jq -r '
    to_entries[]
    | select(.key=="skills" or .key=="mcpServers" or .key=="apps" or .key=="hooks")
    | .key as $k
    | (if (.value|type)=="array" then .value[] elif (.value|type)=="string" then .value else empty end)
    | select(type=="string")
    | [$k, .] | @tsv' "$MANIFEST")
fi

# --- 2. skills/*/SKILL.md frontmatter ------------------------------------------
if [ "$PY" = 1 ]; then
  for s in "$ROOT"/skills/*/SKILL.md; do
    [ -e "$s" ] || continue
    rel="${s#"$ROOT"/}"
    out=$(python3 - "$s" <<'PYEOF' 2>/dev/null || echo "internal-error"
import sys
try:
    import yaml
except ImportError:
    print("no-pyyaml"); sys.exit(0)
lines = open(sys.argv[1], encoding="utf-8", errors="replace").read().splitlines()
if not lines or lines[0].strip() != "---":
    print("no-frontmatter"); sys.exit(0)
end = next((i for i in range(1, len(lines)) if lines[i].strip() == "---"), None)
if end is None:
    print("no-frontmatter"); sys.exit(0)
try:
    data = yaml.safe_load("\n".join(lines[1:end])) or {}
except Exception:
    print("bad-yaml"); sys.exit(0)
if not isinstance(data, dict):
    print("bad-yaml"); sys.exit(0)
missing = [k for k in ("name", "description")
           if not isinstance(data.get(k), str) or not data[k].strip()]
print("missing:" + ",".join(missing) if missing else "ok")
PYEOF
)
    case "$out" in
      ok) : ;;
      no-pyyaml)
        add_finding warn codex-python-missing codex-artifact "$rel" 0 \
          "pyyaml not installed — frontmatter check skipped" ;;
      no-frontmatter)
        add_finding error codex-skill-frontmatter codex-artifact "$rel" 1 \
          "SKILL.md has no closed YAML frontmatter block (--- … ---)" ;;
      bad-yaml)
        add_finding error codex-skill-frontmatter codex-artifact "$rel" 1 \
          "SKILL.md frontmatter is not valid YAML" ;;
      missing:*)
        add_finding error codex-skill-frontmatter codex-artifact "$rel" 1 \
          "SKILL.md frontmatter missing required field(s): ${out#missing:}" ;;
      *)
        add_finding error codex-skill-frontmatter codex-artifact "$rel" 0 \
          "frontmatter check failed to run" ;;
    esac
  done
fi

# --- 3. agents/*.toml -----------------------------------------------------------
if [ "$PY" = 1 ]; then
  for t in "$ROOT"/agents/*.toml; do
    [ -e "$t" ] || continue
    rel="${t#"$ROOT"/}"
    out=$(python3 - "$t" <<'PYEOF' 2>/dev/null || echo "internal-error"
import sys, tomllib
try:
    with open(sys.argv[1], "rb") as f:
        data = tomllib.load(f)
except Exception as e:
    print("parse:" + str(e).replace("\n", " ")[:120]); sys.exit(0)
missing = [k for k in ("name", "description", "developer_instructions")
           if not isinstance(data.get(k), str) or not data[k].strip()]
print("missing:" + ",".join(missing) if missing else "ok")
PYEOF
)
    case "$out" in
      ok) : ;;
      parse:*)
        add_finding error codex-agent-toml codex-artifact "$rel" 0 \
          "agent TOML does not parse: ${out#parse:}" ;;
      missing:*)
        add_finding error codex-agent-toml codex-artifact "$rel" 0 \
          "agent TOML missing required field(s): ${out#missing:} (name, description, developer_instructions are all required)" ;;
      *)
        add_finding error codex-agent-toml codex-artifact "$rel" 0 \
          "agent TOML check failed to run" ;;
    esac
  done
fi

# --- 4. config.toml: parse + legacy profile residue -----------------------------
if [ "$PY" = 1 ]; then
  while IFS= read -r cfg; do
    [ -n "$cfg" ] || continue
    rel="${cfg#"$ROOT"/}"
    out=$(python3 - "$cfg" <<'PYEOF' 2>/dev/null || echo "internal-error"
import sys, tomllib
try:
    with open(sys.argv[1], "rb") as f:
        data = tomllib.load(f)
except Exception as e:
    print("parse:" + str(e).replace("\n", " ")[:120]); sys.exit(0)
if isinstance(data.get("profiles"), dict) and data["profiles"]:
    print("profiles-table:" + ",".join(sorted(data["profiles"])))
if "profile" in data:
    print("profile-key")
print("done")
PYEOF
)
    while IFS= read -r line; do
      case "$line" in
        done) : ;;
        parse:*)
          add_finding error codex-config-unparseable codex-artifact "$rel" 0 \
            "config.toml does not parse: ${line#parse:}" ;;
        profiles-table:*)
          add_finding error codex-legacy-profile codex-artifact "$rel" 0 \
            "legacy [profiles.*] table(s) (${line#profiles-table:}) — removed in v0.134.0, Codex fails at startup; migrate to \$CODEX_HOME/<name>.config.toml overlays" ;;
        profile-key)
          add_finding error codex-legacy-profile codex-artifact "$rel" 0 \
            "legacy top-level profile= key — removed in v0.134.0, Codex fails at startup; use 'codex --profile <name>' instead" ;;
        *)
          add_finding error codex-config-unparseable codex-artifact "$rel" 0 \
            "config.toml check failed to run" ;;
      esac
    done <<< "$out"
  done < <(prune_find config.toml)
fi

# --- 5. hooks.json: parse + known event names ------------------------------------
while IFS= read -r hk; do
  [ -n "$hk" ] || continue
  rel="${hk#"$ROOT"/}"
  if ! jq empty "$hk" >/dev/null 2>&1; then
    add_finding error codex-hooks-unparseable codex-artifact "$rel" 0 \
      "hooks.json is not valid JSON"
    continue
  fi
  while IFS= read -r ev; do
    [ -n "$ev" ] || continue
    add_finding warn codex-hook-unknown-event codex-artifact "$rel" 0 \
      "unknown hook event '$ev' — not one of the 10 lifecycle events (engine v0.114.0); Codex ignores it silently"
  done < <(jq -r --argjson known "$KNOWN_EVENTS" \
    '(.hooks // .) | if type=="object" then keys[] else empty end | select(. as $k | $known | index($k) | not)' "$hk")
done < <(prune_find hooks.json)

render_findings "validate-codex-artifact.sh" "$ROOT"; exit $?
